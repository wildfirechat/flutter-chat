import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/quote_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';

enum ChatInputBarStatus { keyboardStatus, pluginStatus, emojiStatus, recordStatus, muteStatus, pttStatus, menuStatus }

class Mention {
  final String userId;
  final String displayName;
  int start;
  int end; // exclusive

  Mention(this.userId, this.displayName, this.start, this.end);

  @override
  String toString() {
    return 'Mention{userId: $userId, displayName: $displayName, start: $start, end: $end}';
  }
}

/// 控制器类，用于管理输入栏的状态
class MessageInputBarController extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final Conversation conversation;
  final ConversationViewModel conversationViewModel;

  ChatInputBarStatus _status;
  Message? _quotedMessage;
  ChannelInfo? channelInfo;
  Function(Conversation conversation)? onMentionTriggered;
  VoidCallback? onSend;
  final List<Mention> _mentionsList = [];
  String _lastText = "";
  String _conversationDraft = "";
  bool _isInsertingMention = false;
  double _keyboardHeight = 0;

  int _sendTypingTime = 0;
  final Map<String, String> _remoteUrlCache = {};

  MessageInputBarController({
    required this.conversation,
    required this.conversationViewModel,
    ChatInputBarStatus initialStatus = ChatInputBarStatus.keyboardStatus,
  }) : _status = initialStatus {
    // 设置焦点监听器
    focusNode.addListener(_onFocusChanged);
    _loadRemoteUrlCache();

    Imclient.getConversationInfo(conversation).then((conversationInfo) {
      if (conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty) {
        setDraft(conversationInfo.draft!);
      }
    });

    if (conversation.conversationType == ConversationType.Channel) {
      Imclient.getChannelInfo(conversation.target).then((info) {
        if (info != null) {
          channelInfo = info;
          notifyListeners();
        }
      });
    }
  }

  ChatInputBarStatus get status => _status;

  Message? get quotedMessage => _quotedMessage;

  double get keyboardHeight => _keyboardHeight;

  void updateKeyboardHeight(double height) {
    if (height > 0 && _keyboardHeight != height) {
      _keyboardHeight = height;
      notifyListeners();
    }
  }

  void setQuotedMessage(Message? message) {
    _quotedMessage = message;
    notifyListeners();
  }

  void _onFocusChanged() {
    // 当输入框获得焦点时，切换到键盘状态
    if (focusNode.hasFocus && _status != ChatInputBarStatus.keyboardStatus) {
      _status = ChatInputBarStatus.keyboardStatus;
    }
    notifyListeners();
  }

  void setStatus(ChatInputBarStatus newStatus) {
    if (_status == newStatus) return;

    _status = newStatus;

    // 根据新状态管理焦点
    if (newStatus == ChatInputBarStatus.keyboardStatus) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    } else if (newStatus == ChatInputBarStatus.pluginStatus || newStatus == ChatInputBarStatus.emojiStatus || newStatus == ChatInputBarStatus.menuStatus) {
      if (focusNode.hasFocus) {
        focusNode.unfocus();
      }
    }

    notifyListeners();
  }

  void resetStatus() {
    if (_status == ChatInputBarStatus.pluginStatus || _status == ChatInputBarStatus.emojiStatus || _status == ChatInputBarStatus.menuStatus) {
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

  void onMenuButton() {
    if (_status == ChatInputBarStatus.menuStatus) {
      setStatus(ChatInputBarStatus.keyboardStatus);
    } else {
      setStatus(ChatInputBarStatus.menuStatus);
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
      _quotedMessage = null;
      _mentionsList.clear();
      if (_conversationDraft.isNotEmpty) {
        Imclient.setConversationDraft(conversation, '');
        _conversationDraft = '';
      }
      _lastText = "";
      onSend?.call();
      notifyListeners();
    }
  }

  void onTextChanged(String text) {
    if (_isInsertingMention) {
      if (text != _lastText) {
        debugPrint('Spurious text change detected ("$text"). Restoring to "$_lastText"');
        textEditingController.value = TextEditingValue(
          text: _lastText,
          selection: TextSelection.fromPosition(TextPosition(offset: _lastText.length)),
        );
        return;
      }
    } else {
      // Regular logic for triggering mention picker on user input
      if (text.isNotEmpty && text.endsWith('@')) {
        if (text.length > _lastText.length && text.substring(text.length - 1) == '@') {
          if (onMentionTriggered != null) {
            onMentionTriggered!(conversation);
          }
        }
      }
    }

    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(text);
    }

    _lastText = text;
    _sendTyping(text);
    notifyListeners();
  }

  void _handleMentionsChange(String newText) {
    int len1 = _lastText.length;
    int len2 = newText.length;
    int delta = len2 - len1;

    int start = 0;
    int minLen = len1 < len2 ? len1 : len2;
    while (start < minLen && _lastText[start] == newText[start]) {
      start++;
    }

    if (delta < 0) {
      // Deletion
      int deletedLen = -delta;
      int deletedEnd = start + deletedLen;

      List<Mention> toRemove = [];
      for (var mention in _mentionsList) {
        if (mention.start < deletedEnd && mention.end > start) {
          toRemove.add(mention);
        } else if (mention.start >= deletedEnd) {
          mention.start += delta;
          mention.end += delta;
        }
      }

      if (toRemove.isNotEmpty) {
        _mentionsList.removeWhere((m) => toRemove.contains(m));
        toRemove.sort((a, b) => b.start.compareTo(a.start));

        String tempText = newText;
        for (var m in toRemove) {
          int debrisStart = m.start < start ? m.start : start;
          int debrisEnd = m.end > deletedEnd ? m.end - deletedLen : start;

          if (debrisEnd > debrisStart) {
            tempText = tempText.replaceRange(debrisStart, debrisEnd, "");
            int shift = debrisEnd - debrisStart;
            for (var other in _mentionsList) {
              if (other.start >= debrisStart) {
                other.start -= shift;
                other.end -= shift;
              }
            }
          }
        }

        if (tempText != newText) {
          // Update text and cursor
          // Find where to put cursor.
          // We want it at the start of the first removed mention (in the new text coordinates)
          // But we processed in reverse.
          // The 'start' of the edit is a good approximation, or the debrisStart of the last processed (first in text).

          var firstRemoved = toRemove.last;
          int firstDebrisStart = firstRemoved.start < start ? firstRemoved.start : start;

          textEditingController.value = TextEditingValue(
            text: tempText,
            selection: TextSelection.collapsed(offset: firstDebrisStart),
          );
          _lastText = tempText;
          return; // _lastText updated, exit to avoid double update
        }
      }
    } else if (delta > 0) {
      // Insertion
      List<Mention> toRemove = [];
      for (var mention in _mentionsList) {
        if (mention.start >= start) {
          mention.start += delta;
          mention.end += delta;
        } else if (mention.end > start) {
          // Insertion inside a mention
          toRemove.add(mention);
        }
      }
      _mentionsList.removeWhere((m) => toRemove.contains(m));
    }
  }

  void addMention(UserInfo user) {
    _isInsertingMention = true;

    final String name = user.displayName ?? user.userId;
    final TextEditingValue currentVal = textEditingController.value;
    final String currentText = currentVal.text;
    final int selectionStart = currentVal.selection.start;

    final int atSignIndex = selectionStart - 1;

    final String textToInsert = "@$name ";
    final String newText = currentText.replaceRange(atSignIndex, selectionStart, textToInsert);
    final int newCursorPos = atSignIndex + textToInsert.length;

    textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(TextPosition(offset: newCursorPos)),
    );

    _lastText = newText;
    final mentionEnd = newCursorPos - 1; // -1 to exclude the trailing space
    _mentionsList.add(Mention(user.userId, name, atSignIndex, mentionEnd));

    Future.delayed(const Duration(milliseconds: 150), () {
      _isInsertingMention = false;
    });
  }

  void _sendTextMessage(Conversation conversation, String text) async {
    TextMessageContent txt = TextMessageContent(text);
    if (_quotedMessage != null) {
      txt.quoteInfo = await QuoteInfo.fromMessage(_quotedMessage!);
    }
    List<String> mentionedUsers = _mentionsList.map((e) => e.userId).toList();
    if (mentionedUsers.isNotEmpty) {
      if (mentionedUsers.contains('All')) {
        txt.mentionedType = 2;
        txt.mentionedTargets = [];
      } else {
        txt.mentionedType = 1;
        txt.mentionedTargets = mentionedUsers;
      }
    }
    conversationViewModel.sendMessage(txt);
    _sendTypingTime = 0;
  }

  void _loadRemoteUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('wfc_sticker_remote_urls');
      if (jsonStr != null) {
        final Map<String, dynamic> map = json.decode(jsonStr);
        map.forEach((key, value) {
          _remoteUrlCache[key] = value.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading remote url cache: $e');
    }
  }

  void _saveRemoteUrl(String stickerPath, String remoteUrl) async {
    _remoteUrlCache[stickerPath] = remoteUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wfc_sticker_remote_urls', json.encode(_remoteUrlCache));
    } catch (e) {
      debugPrint('Error saving remote url: $e');
    }
  }

  final Map<String, _StickerInfo> _stickerCache = {};

  Future<void> sendSticker(String stickerPath) async {
    try {
      StickerMessageContent content = StickerMessageContent();

      // 1. Check if we have a remoteUrl persisted
      if (_remoteUrlCache.containsKey(stickerPath)) {
        content.remoteUrl = _remoteUrlCache[stickerPath];
        // We still need width/height if possible, check stickerCache
        _StickerInfo? info = _stickerCache[stickerPath];
        if (info != null) {
          content.width = info.width;
          content.height = info.height;
        } else {
          // If not in memory cache, we might want to load it once to get dimensions
          final byteData = await rootBundle.load(stickerPath);
          final image = await decodeImageFromList(byteData.buffer.asUint8List());
          content.width = image.width;
          content.height = image.height;
          _stickerCache[stickerPath] = _StickerInfo(path: '', width: image.width, height: image.height);
        }
        conversationViewModel.sendMessage(content);
        onSend?.call();
        return;
      }

      // 2. No remoteUrl, use localPath and upload
      _StickerInfo? info = _stickerCache[stickerPath];
      if (info == null || info.path.isEmpty) {
        final byteData = await rootBundle.load(stickerPath);
        final tempDir = await getTemporaryDirectory();
        final fileName = stickerPath.split('/').last;
        final file = File('${tempDir.path}/$fileName');

        if (!await file.exists()) {
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }

        int width = 0;
        int height = 0;
        try {
          final image = await decodeImageFromList(byteData.buffer.asUint8List());
          width = image.width;
          height = image.height;
        } catch (e) {
          debugPrint('Error decoding image: $e');
        }

        info = _StickerInfo(path: file.path, width: width, height: height);
        _stickerCache[stickerPath] = info;
      }

      content.localPath = info.path;
      content.width = info.width;
      content.height = info.height;

      conversationViewModel.sendMediaMessage(content, uploadedCallback: (remoteUrl) {
        _saveRemoteUrl(stickerPath, remoteUrl);
      });
      onSend?.call();
    } catch (e) {
      debugPrint('Error sending sticker: $e');
    }
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
    _lastText = draft;
    _conversationDraft = draft;
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

    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(newText);
    }
    _lastText = newText;

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
      if (_mentionsList.isNotEmpty) {
        _handleMentionsChange(newText);
      }
      _lastText = newText;
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

    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(newText);
    }
    _lastText = newText;

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

class _StickerInfo {
  final String path;
  final int width;
  final int height;

  _StickerInfo({required this.path, required this.width, required this.height});
}
