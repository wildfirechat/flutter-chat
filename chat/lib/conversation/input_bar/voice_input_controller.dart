import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:chat/asr/asr_error.dart';
import 'package:chat/asr/asr_manager.dart';
import 'package:chat/config.dart';
import 'message_input_bar_controller.dart';

/// 实时语音输入的状态
enum VoiceInputState {
  /// 空闲
  idle,

  /// 录音中，识别结果实时写入输入框
  recording,

  /// 已停止录音，等待剩余识别结果
  finishing,
}

/// 实时语音输入：边说边把识别结果写入输入框。移动端交互参考 android-chat，PC 端参考 vue-pc-chat：
/// - 点击语音输入按钮开始录音，再次点击停止录音，剩余识别结果返回后结束；
/// - 识别结果写入开始时的光标处，有选中的文本时替换选中的文本；之后识别文本每次更新，都整体替换这段文本；
/// - 用户编辑输入框（打字、删除、粘贴、插入表情等，凡不是本类写入的文本变化）、发送消息、
///   输入框被换掉（按住说话、频道菜单）、切换会话时结束语音输入，丢弃还没返回的识别结果，已写入的文本保持不变；
/// - 移动端用户移动光标也会结束语音输入；PC 端光标可以随意点，识别文本照常更新。
///
/// 生命周期跟随 [MessageInputBarController]（一个会话一个），由它在上述时机调用 [cancel]。
class VoiceInputController extends ChangeNotifier {
  VoiceInputController(this._inputBar,
      {required this.cancelOnSelectionChange});

  final MessageInputBarController _inputBar;

  /// 用户移动光标时是否结束语音输入
  final bool cancelOnSelectionChange;

  /// 是否配置了实时语音输入服务，没有配置时不显示语音输入按钮
  static bool get isAvailable =>
      Config.asrStreamServerUrl?.isNotEmpty ?? false;

  final AsrManager _asrManager = AsrManager();
  VoiceInputState _state = VoiceInputState.idle;

  // 识别文本在输入框中的范围 [_textStart, _textEnd)，识别结果会整体替换这个范围内的文本
  int _textStart = 0;
  int _textEnd = 0;

  // 本类最近一次写入之后输入框的值，和它不一致的变化是用户自己的编辑
  TextEditingValue _expectedValue = TextEditingValue.empty;

  // 正在由本类修改输入框，期间的变化不算用户编辑
  bool _isUpdatingText = false;
  bool _disposed = false;

  VoiceInputState get state => _state;

  /// 点击语音输入按钮：空闲时开始，录音中时停止录音，等待剩余识别结果时忽略
  void toggle({required ValueChanged<AsrError> onError}) {
    switch (_state) {
      case VoiceInputState.idle:
        _start(onError);
      case VoiceInputState.recording:
        _setState(VoiceInputState.finishing);
        _asrManager.stopRecognition();
      case VoiceInputState.finishing:
        break;
    }
  }

  /// 结束语音输入，丢弃还没返回的识别结果，已写入输入框的文本保持不变
  void cancel() {
    if (_state == VoiceInputState.idle) {
      return;
    }
    _asrManager.cancelRecognition();
    _reset();
  }

  void _start(ValueChanged<AsrError> onError) {
    final TextEditingController textController =
        _inputBar.textEditingController;
    if (!textController.selection.isValid) {
      // 输入框还没有光标时写到末尾。先把光标放好，获取焦点时框架就不会再改选区
      _updateText(() => textController.selection =
          TextSelection.collapsed(offset: textController.text.length));
    }
    final TextSelection selection = textController.selection;
    _textStart = selection.start;
    _textEnd = selection.end;
    _expectedValue = textController.value;
    textController.addListener(_onEditingValueChanged);
    _setState(VoiceInputState.recording);
    // 输入框获取焦点，移动端同时弹出软键盘
    if (!_inputBar.focusNode.hasFocus) {
      _inputBar.focusNode.requestFocus();
    }

    _asrManager.startRecognition(
      onPartialResult: _replaceRecognizedText,
      onFinalResult: (text) {
        // 没有识别出文字时，保留原来选中的文本
        if (text.isNotEmpty) {
          _replaceRecognizedText(text);
        }
        _reset();
      },
      onError: (error) {
        _reset();
        onError(error);
      },
    );
  }

  void _onEditingValueChanged() {
    if (_isUpdatingText || _state == VoiceInputState.idle) {
      return;
    }
    final TextEditingValue value = _inputBar.textEditingController.value;
    if (value.text != _expectedValue.text) {
      cancel();
      return;
    }
    // 只比较位置：输入法回传的选区可能只有 affinity 不同；失去焦点等情况下选区无效，也不算用户移动光标
    final TextSelection selection = value.selection;
    final TextSelection expected = _expectedValue.selection;
    if (cancelOnSelectionChange &&
        selection.isValid &&
        (selection.baseOffset != expected.baseOffset ||
            selection.extentOffset != expected.extentOffset)) {
      cancel();
    }
  }

  /// 用识别文本整体替换输入框中的识别文本
  void _replaceRecognizedText(String text) {
    final TextEditingController textController =
        _inputBar.textEditingController;
    final int length = textController.text.length;
    final int start = math.min(_textStart, length);
    final int end = math.min(math.max(_textEnd, start), length);
    final int newEnd = start + text.length;
    final TextSelection selection =
        _selectionAfterReplace(textController.selection, start, end, newEnd);
    _updateText(
        () => _inputBar.replaceTextRange(start, end, text, selection));
    _textEnd = newEnd;
    _expectedValue = textController.value;
  }

  /// 把 [start, end) 替换成 [start, newEnd) 之后的选区
  TextSelection _selectionAfterReplace(
      TextSelection current, int start, int end, int newEnd) {
    // 移动端光标始终跟在识别文本末尾（用户移动光标会结束语音输入）；
    // PC 端光标原本在识别文本末尾、或者选中的正是被替换的文本时跟随，否则留在用户点的位置
    if (cancelOnSelectionChange ||
        !current.isValid ||
        (current.start == start && current.end == end)) {
      return TextSelection.collapsed(offset: newEnd);
    }
    int mapOffset(int offset) {
      if (offset >= end) {
        return offset + newEnd - end;
      }
      if (offset > start) {
        return math.min(offset, newEnd);
      }
      return offset;
    }

    return TextSelection(
      baseOffset: mapOffset(current.baseOffset),
      extentOffset: mapOffset(current.extentOffset),
    );
  }

  void _updateText(VoidCallback update) {
    _isUpdatingText = true;
    try {
      update();
    } finally {
      _isUpdatingText = false;
    }
  }

  void _reset() {
    _inputBar.textEditingController.removeListener(_onEditingValueChanged);
    _setState(VoiceInputState.idle);
  }

  void _setState(VoiceInputState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    super.dispose();
  }
}
