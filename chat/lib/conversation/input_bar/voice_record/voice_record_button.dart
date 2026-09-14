import 'package:flutter/material.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';

import 'package:chat/asr/asr_error.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import '../message_input_bar_controller.dart';
import '../voice_input_controller.dart';
import 'voice_record_controller.dart';
import 'voice_record_geometry.dart';
import 'voice_record_overlay.dart';

/// 输入栏的「按住 说话」按钮（android-chat 交互）：按下立即开始录音并显示全屏浮层，
/// 手指移动选择发送、取消或转文字，松开结束。浮层见 [VoiceRecordOverlay]，逻辑见 [VoiceRecordController]
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.inputBar,
    required this.stageKey,
  });

  final MessageInputBarController inputBar;

  /// 输入栏的 key。浮层的操作区只覆盖它的宽度，平板双栏时不会延伸到左栏
  final GlobalKey stageKey;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with WidgetsBindingObserver {
  late final VoiceRecordController _controller;
  late final _VoiceRecordPopEntry _popEntry;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  VoiceRecordLayout? _layout;
  ModalRoute<Object?>? _route;

  // 按住按钮的那根手指，其他手指忽略
  int? _pointer;
  bool _pressed = false;

  // 发送语音、提示错误可能在按钮销毁之后，不能再用 context 取
  late AppLocalizations _l10n;
  late ConversationController _conversationController;

  @override
  void initState() {
    super.initState();
    final MessageInputBarController inputBar = widget.inputBar;
    final Conversation conversation = inputBar.conversation;
    final ConversationViewModel viewModel = inputBar.conversationViewModel;
    _controller = VoiceRecordController(
      speechToTextEnabled: VoiceInputController.isAvailable,
      onRecordStart: () => viewModel
          .sendMessage(TypingMessageContent()..type = TypingType.Typing_VOICE),
      onSendVoice: (path, duration) {
        // 语音在录音停止、编码完成后才发送，这时可能已经离开了会话，按录音时的会话发送
        _conversationController.onSoundRecorded(conversation, path, duration);
        if (mounted) {
          widget.inputBar.onSend?.call();
        }
      },
      onSendText: (text) {
        viewModel.sendMessage(TextMessageContent(text));
        widget.inputBar.onSend?.call();
      },
      onError: _showError,
    );
    _controller.addListener(_onControllerChanged);
    _popEntry = _VoiceRecordPopEntry(() => _controller.handleBack());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
    _conversationController =
        Provider.of<ConversationController>(context, listen: false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dismissNow();
    final bool overlayShown = _overlayEntry != null;
    _removeOverlay();
    _popEntry.dispose();
    final VoiceRecordController controller = _controller;
    if (overlayShown) {
      // 浮层到下一帧才真正卸载，卸载之后再释放它用到的 TextEditingController 等
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    } else {
      controller.dispose();
    }
    super.dispose();
  }

  /// 系统返回键的兜底，见 [_VoiceRecordPopEntry]
  @override
  Future<bool> didPopRoute() async => _controller.handleBack();

  @override
  void didChangeMetrics() {
    // 旋转屏幕、调整分屏宽度后浮层各部分的位置都不对了，直接关闭，和 android-chat 界面重建时一样
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final VoiceRecordLayout? layout = _layout;
      final RenderBox? overlayBox = _overlayBox;
      if (!mounted ||
          _overlayEntry == null ||
          layout == null ||
          overlayBox == null ||
          !overlayBox.hasSize) {
        return;
      }
      if (overlayBox.size.width != layout.size.width) {
        _controller.dismissNow();
      }
    });
  }

  void _showError(AsrError error) {
    showToast(
      msg: error.kind == AsrErrorKind.noPermission
          ? _l10n.noMicrophonePermission
          : _l10n.recordFailed(error.detail ?? ''),
    );
  }

  void _onControllerChanged() {
    final bool showing = _controller.stage != VoiceRecordStage.idle;
    if (showing && _overlayEntry == null) {
      _showOverlay();
    } else if (!showing && _overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    final VoiceRecordLayout? layout = _layout;
    if (layout == null) {
      return;
    }
    final OverlayEntry entry = OverlayEntry(
      builder: (context) =>
          VoiceRecordOverlay(controller: _controller, layout: layout),
    );
    _overlayEntry = entry;
    // 插到根 Overlay，遮罩盖住整个窗口（平板双栏时也盖住左栏）
    Overlay.of(context, rootOverlay: true).insert(entry);
    WidgetsBinding.instance.addObserver(this);
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    route?.registerPopEntry(_popEntry);
    _route = route;
  }

  void _removeOverlay() {
    final OverlayEntry? entry = _overlayEntry;
    if (entry == null) {
      return;
    }
    _overlayEntry = null;
    entry.remove();
    entry.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _route?.unregisterPopEntry(_popEntry);
    _route = null;
  }

  RenderBox? get _overlayBox =>
      Overlay.maybeOf(context, rootOverlay: true)?.context.findRenderObject()
          as RenderBox?;

  /// 按当前的位置计算浮层布局，坐标相对于根 Overlay
  VoiceRecordLayout? _computeLayout() {
    final RenderBox? overlayBox = _overlayBox;
    final RenderObject? stageBox =
        widget.stageKey.currentContext?.findRenderObject();
    final RenderObject? buttonBox =
        _buttonKey.currentContext?.findRenderObject();
    if (overlayBox == null ||
        stageBox is! RenderBox ||
        buttonBox is! RenderBox ||
        !overlayBox.hasSize ||
        !stageBox.hasSize ||
        !buttonBox.hasSize) {
      return null;
    }
    return VoiceRecordLayout(
      size: overlayBox.size,
      stage: MatrixUtils.transformRect(
          stageBox.getTransformTo(overlayBox), Offset.zero & stageBox.size),
      buttonTop: MatrixUtils.transformPoint(
              buttonBox.getTransformTo(overlayBox), Offset.zero)
          .dy,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    _pointer = event.pointer;
    if (_controller.stage == VoiceRecordStage.dismissing) {
      // 上一次录音的浮层还在退出，直接关闭
      _controller.dismissNow();
    }
    if (_controller.stage != VoiceRecordStage.idle) {
      return;
    }
    final VoiceRecordLayout? layout = _computeLayout();
    if (layout == null) {
      return;
    }
    _layout = layout;
    setState(() => _pressed = true);
    _controller.start();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final VoiceRecordLayout? layout = _layout;
    final RenderBox? overlayBox = _overlayBox;
    if (event.pointer != _pointer ||
        _controller.stage != VoiceRecordStage.recording ||
        layout == null ||
        overlayBox == null) {
      return;
    }
    _controller.updateZone(layout.zoneAt(
      overlayBox.globalToLocal(event.position),
      speechToTextEnabled: _controller.speechToTextEnabled,
    ));
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    if (_pressed) {
      setState(() => _pressed = false);
    }
    _controller.release();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOutSine,
          child: Container(
            key: _buttonKey,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed ? colors.cellHover : colors.surface,
              border: _pressed ? Border.all(color: colors.hairline) : null,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              AppLocalizations.of(context)!.holdToTalk,
              style: AppText.lg.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// 浮层显示时拦截返回键，等同于取消
///
/// 返回键先交给根 Navigator：会话页所在的路由注册了它就不能直接弹出，由 [onPopInvokedWithResult] 取消录音。
/// 平板双栏时会话页在右栏的嵌套 Navigator 里，右栏只有会话页一页时返回键到不了这里，
/// 由 [_VoiceRecordButtonState.didPopRoute] 兜底；注册它也让 Android 预测性返回下框架接管返回键，兜底才收得到
class _VoiceRecordPopEntry extends PopEntry<Object?> {
  _VoiceRecordPopEntry(this.onBack);

  final VoidCallback onBack;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(false);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop) {
      onBack();
    }
  }

  void dispose() => canPopNotifier.dispose();
}
