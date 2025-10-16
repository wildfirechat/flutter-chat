import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

enum ChatInputBarStatus { keyboardStatus, pluginStatus, emojiStatus, recordStatus, muteStatus, pttStatus }

/// 控制器类，用于管理输入栏的状态
class MessageInputBarController extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final Conversation conversation;
  final ConversationViewModel conversationViewModel;

  ChatInputBarStatus _status;

  int _sendTypingTime = 0;

  MessageInputBarController({
    required this.conversation,
    required this.conversationViewModel,
    ChatInputBarStatus initialStatus = ChatInputBarStatus.keyboardStatus,
  }) : _status = initialStatus {
    // 设置焦点监听器
    focusNode.addListener(_onFocusChanged);

    Imclient.getConversationInfo(conversation).then((conversationInfo) {
      if (conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty) {
        setDraft(conversationInfo.draft!);
      }
    });
  }

  ChatInputBarStatus get status => _status;

  void _onFocusChanged() {
    if (focusNode.hasFocus && _status != ChatInputBarStatus.keyboardStatus) {
      _status = ChatInputBarStatus.keyboardStatus;
      notifyListeners();
    }
  }

  void setStatus(ChatInputBarStatus newStatus) {
    if (_status == newStatus) return;

    _status = newStatus;

    // 根据新状态管理焦点
    if (newStatus == ChatInputBarStatus.keyboardStatus) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    } else if (newStatus == ChatInputBarStatus.pluginStatus || newStatus == ChatInputBarStatus.emojiStatus) {
      if (focusNode.hasFocus) {
        focusNode.unfocus();
      }
    }

    notifyListeners();
  }

  void resetStatus() {
    if (_status == ChatInputBarStatus.pluginStatus || _status == ChatInputBarStatus.emojiStatus) {
      _status = ChatInputBarStatus.keyboardStatus;
      notifyListeners();
    }
    focusNode.unfocus();
  }

  void onPluginButton() {
    if (_status == ChatInputBarStatus.pluginStatus) {
      setStatus(ChatInputBarStatus.keyboardStatus);
    } else {
      setStatus(ChatInputBarStatus.pluginStatus);
    }
  }

  void onEmojiButton() {
    if (_status == ChatInputBarStatus.emojiStatus) {
      setStatus(ChatInputBarStatus.keyboardStatus);
    } else {
      setStatus(ChatInputBarStatus.emojiStatus);
    }
  }

  void onVoiceButton() {
    setStatus(ChatInputBarStatus.recordStatus);
  }

  void onKeyboardButton() {
    setStatus(ChatInputBarStatus.keyboardStatus);
  }

  void onSendButton() {
    if (textEditingController.text.isNotEmpty) {
      _sendTextMessage(conversation, textEditingController.text.trim());
      textEditingController.clear();
      notifyListeners();
    }
  }

  void onTextChanged(String text) {
    _sendTyping(text);
    notifyListeners();
  }

  void _sendTextMessage(Conversation conversation, String text) {
    TextMessageContent txt = TextMessageContent(text);
    conversationViewModel.sendMessage(txt);
    _sendTypingTime = 0;
  }

  void _sendTyping(String text) {
    if (DateTime.now().second - _sendTypingTime > 12 && text.isNotEmpty) {
      _sendTypingTime = DateTime.now().microsecondsSinceEpoch;
      TypingMessageContent typingMessageContent = TypingMessageContent();
      typingMessageContent.type = TypingType.Typing_TEXT;

      conversationViewModel.sendMessage(typingMessageContent);
    }
  }

  String getDraft() {
    return textEditingController.text;
  }

  void setDraft(String draft) {
    textEditingController.text = draft;
    textEditingController.selection = TextSelection(baseOffset: draft.length, extentOffset: draft.length);
    notifyListeners();
  }

  void insertText(String text) {
    final currentText = textEditingController.text;
    final selection = textEditingController.selection;
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      text,
    );

    textEditingController.text = newText;
    textEditingController.selection = selection.copyWith(
      baseOffset: selection.start + text.length,
      extentOffset: selection.start + text.length,
    );

    notifyListeners();
  }

  void backspace(List<String> emojis) {
    final text = textEditingController.text;
    final selection = textEditingController.selection;
    final selectionLength = selection.end - selection.start;

    // 有选择的文本
    if (selectionLength > 0) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '',
      );
      textEditingController.text = newText;
      textEditingController.selection = selection.copyWith(
        baseOffset: selection.start,
        extentOffset: selection.start,
      );
      notifyListeners();
      return;
    }

    // 光标在最开始
    if (selection.start == 0) {
      return;
    }

    // 删除前一个字符，考虑表情符号可能占两个字符
    int charSize = 1;
    if (selection.start > 1) {
      String sub = text.substring(selection.start - 2, selection.start);
      if (emojis.contains(sub)) {
        charSize = 2;
      }
    }

    int newStart = selection.start - charSize;
    int newEnd = selection.start;
    final newText = text.replaceRange(
      newStart,
      newEnd,
      '',
    );

    textEditingController.text = newText;
    textEditingController.selection = selection.copyWith(
      baseOffset: newStart,
      extentOffset: newStart,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    textEditingController.dispose();
    focusNode.removeListener(_onFocusChanged);
    focusNode.dispose();
  }
}
