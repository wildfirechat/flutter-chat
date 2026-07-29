import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/quote_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/utilities.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'draft_data.dart';

enum ChatInputBarStatus { keyboardStatus, pluginStatus, emojiStatus, recordStatus, muteStatus, pttStatus, menuStatus }

/// 内联图片在输入框文本中的占位字符(U+FFFC OBJECT REPLACEMENT CHARACTER)。
/// 第 N 个占位符对应 [MessageInputBarController._inlineAttachments] 的第 N 项。
const String _inlineAttachmentPlaceholder = '\uFFFC';

/// 粘贴进输入框的一个内联附件(图片或文件),对应文本中的一个占位符
/// (见 [_inlineAttachmentPlaceholder])。图片内联显示原图,文件显示为
/// 文件卡片;发送时图片发图片消息,文件发文件消息(微信 PC 交互)。
class InlineAttachment {
  final String path;

  /// 非空表示文件卡片,null 表示内联图片。
  final String? fileName;
  final int fileSize;

  const InlineAttachment.image(this.path)
      : fileName = null,
        fileSize = 0;

  const InlineAttachment.file(this.path, String this.fileName, this.fileSize);

  bool get isFile => fileName != null;
}

int _countInlineAttachmentPlaceholders(String text) {
  int count = 0;
  for (int i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0xFFFC) count++;
  }
  return count;
}

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
  final EmojiTextEditingController textEditingController = EmojiTextEditingController();
  final FocusNode focusNode = FocusNode();
  final Conversation conversation;
  final ConversationViewModel conversationViewModel;

  ChatInputBarStatus _status;
  Message? _quotedMessage;
  QuoteInfo? _quoteInfo;
  ChannelInfo? channelInfo;
  Function(Conversation conversation)? onMentionTriggered;
  VoidCallback? onSend;
  final List<Mention> _mentionsList = [];

  // 粘贴到输入框的内联附件(图片/文件),按占位符出现顺序一一对应(见 _inlineAttachmentPlaceholder)。
  // 仅在内存中维护:草稿不保存附件,切换会话即丢弃。
  final List<InlineAttachment> _inlineAttachments = [];
  String _lastText = "";
  String _conversationDraft = "";
  bool _isInsertingMention = false;
  double _keyboardHeight = 0;

  // 进行中的 @ 会话:用户键入 '@' 开启,_mentionAtIndex 是 '@' 的下标(-1 表示无会话),
  // _mentionQuery 是 '@' 与光标之间的过滤词。移动端经 onMentionTriggered 跳选人页,
  // 桌面端由 @ 浮层监听 hasMentionSession/mentionQuery 就地过滤(微信 PC 交互)。
  int _mentionAtIndex = -1;
  String _mentionQuery = '';

  int _sendTypingTime = 0;
  final Map<String, String> _remoteUrlCache = {};
  Timer? _saveDraftTimer;
  StreamSubscription<ConversationDraftUpdatedEvent>? _draftUpdatedSubscription;

  MessageInputBarController({
    required this.conversation,
    required this.conversationViewModel,
    ChatInputBarStatus initialStatus = ChatInputBarStatus.keyboardStatus,
  }) : _status = initialStatus {
    // 设置焦点监听器
    focusNode.addListener(_onFocusChanged);
    // 纯光标移动不会触发 onTextChanged,需单独校验 @ 会话
    textEditingController.addListener(_onEditingValueChanged);
    // 渲染层按占位符序号取对应附件,内联显示在输入框里
    textEditingController.inlineAttachmentResolver =
        (ordinal) => ordinal < _inlineAttachments.length ? _inlineAttachments[ordinal] : null;
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

    _draftUpdatedSubscription = Imclient.IMEventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      if (event.conversation != conversation) return;
      final currentDraft = getDraft();
      // 仅当本地未编辑（当前草稿与上次加载/保存的草稿一致）且远程草稿变化时才更新，
      // 避免本地输入被远端同步覆盖。
      if (currentDraft == _conversationDraft && event.draft != _conversationDraft) {
        setDraft(event.draft);
      }
    });
  }

  String get conversationDraft => _conversationDraft;

  ChatInputBarStatus get status => _status;

  Message? get quotedMessage => _quotedMessage;

  QuoteInfo? get quoteInfo => _quoteInfo;

  bool get hasQuote => _quotedMessage != null || _quoteInfo != null;

  bool get hasMentionSession => _mentionAtIndex >= 0;

  /// 进行中的 @ 会话里 '@' 在文本中的下标(无会话为 -1)。
  /// 桌面端浮层用它定位 '@' 的光标矩形,把浮层贴到 '@' 上方。
  int get mentionAtIndex => _mentionAtIndex;

  String get mentionQuery => _mentionQuery;

  double get keyboardHeight => _keyboardHeight;

  void updateKeyboardHeight(double height) {
    if (height > 0 && _keyboardHeight != height) {
      _keyboardHeight = height;
      notifyListeners();
    }
  }

  void setQuotedMessage(Message? message) async {
    _quotedMessage = message;
    if (message != null) {
      _quoteInfo = await QuoteInfo.fromMessage(message);
    } else {
      _quoteInfo = null;
    }
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
    // 以文本中实际存在的占位符数为准,防止极端场景(如 undo)下列表残留看不见的附件
    final int placeholderCount = _countInlineAttachmentPlaceholders(textEditingController.text);
    final List<InlineAttachment> attachments = _inlineAttachments.take(placeholderCount).toList();
    final String text = textEditingController.text.replaceAll(_inlineAttachmentPlaceholder, '').trim();
    if (attachments.isEmpty && text.isEmpty) {
      return;
    }
    // 先把内联附件按序逐个发出,再发文本(引用/@提醒随文本消息)
    for (final attachment in attachments) {
      if (attachment.isFile) {
        conversationViewModel.sendMediaMessage(FileMessageContent()
          ..name = attachment.fileName!
          ..size = attachment.fileSize
          ..localPath = attachment.path);
      } else {
        conversationViewModel.sendMediaMessage(ImageMessageContent()..localPath = attachment.path);
      }
    }
    if (text.isNotEmpty) {
      _sendTextMessage(conversation, text);
    }
    _inlineAttachments.clear();
    textEditingController.clear();
    _quotedMessage = null;
    _quoteInfo = null;
    _mentionsList.clear();
    _endMentionSession();
    if (_conversationDraft.isNotEmpty) {
      Imclient.setConversationDraft(conversation, '');
      _conversationDraft = '';
    }
    _lastText = "";
    onSend?.call();
    notifyListeners();
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
      _updateMentionSession(text);
    }

    text = _syncInlineAttachments(text);

    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(text);
    }

    _lastText = text;
    _sendTyping(text);
    _scheduleSaveDraft();
    notifyListeners();
  }

  /// 在光标处插入一张内联图片(微信 PC 交互:粘贴的图片直接显示在输入框里)。
  void insertInlineImage(String path) => _insertInlineAttachment(InlineAttachment.image(path));

  /// 在光标处插入一个内联文件卡片(微信 PC 交互:粘贴的文件以卡片显示在输入框里)。
  void insertInlineFile(String path, String name, int size) =>
      _insertInlineAttachment(InlineAttachment.file(path, name, size));

  /// 文本中插入占位字符,附件按占位符序号登记;选区若圈住已有附件则一并替换。
  void _insertInlineAttachment(InlineAttachment attachment) {
    final String text = textEditingController.text;
    TextSelection selection = textEditingController.selection;
    if (!selection.isValid || selection.start < 0) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    final int start = selection.start;
    final int end = selection.end;
    final int before = _countInlineAttachmentPlaceholders(text.substring(0, start));
    final int inside = _countInlineAttachmentPlaceholders(text.substring(start, end));
    if (inside > 0) {
      _inlineAttachments.removeRange(before, math.min(before + inside, _inlineAttachments.length));
    }
    final String newText = text.replaceRange(start, end, _inlineAttachmentPlaceholder);
    _inlineAttachments.insert(before, attachment);

    textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(newText);
    }
    _lastText = newText;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    notifyListeners();
  }

  /// 用户编辑后同步内联附件与占位符:删掉占位符时移除对应附件;
  /// 粘贴文本里混入的外来 U+FFFC 一律剔除,避免占位符与附件错位。
  /// 必须在 _lastText 更新前调用;返回(可能被改写的)最新文本。
  String _syncInlineAttachments(String text) {
    if (_inlineAttachments.isEmpty && !text.contains(_inlineAttachmentPlaceholder)) {
      return text;
    }
    final String old = _lastText;
    int prefix = 0;
    final int minLen = math.min(old.length, text.length);
    while (prefix < minLen && old.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
      prefix++;
    }
    // 相邻占位符是同一字符,退格删除时前后缀 diff 无法区分删的是哪个,用光标位置消歧
    final TextSelection selection = textEditingController.selection;
    if (text.length < old.length && selection.isValid && selection.isCollapsed && selection.start < prefix) {
      prefix = selection.start;
    }
    int suffix = 0;
    while (suffix < minLen - prefix &&
        old.codeUnitAt(old.length - 1 - suffix) == text.codeUnitAt(text.length - 1 - suffix)) {
      suffix++;
    }

    final String removed = old.substring(prefix, old.length - suffix);
    final int removedCount = _countInlineAttachmentPlaceholders(removed);
    if (removedCount > 0) {
      final int before = _countInlineAttachmentPlaceholders(old.substring(0, prefix));
      final int rangeStart = math.min(before, _inlineAttachments.length);
      final int rangeEnd = math.min(before + removedCount, _inlineAttachments.length);
      if (rangeStart < rangeEnd) {
        _inlineAttachments.removeRange(rangeStart, rangeEnd);
      }
    }

    final String inserted = text.substring(prefix, text.length - suffix);
    if (_countInlineAttachmentPlaceholders(inserted) > 0) {
      final String cleaned = inserted.replaceAll(_inlineAttachmentPlaceholder, '');
      text = text.replaceRange(prefix, text.length - suffix, cleaned);
      textEditingController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: prefix + cleaned.length),
      );
    }
    return text;
  }

  /// 微信式 @ 会话跟踪:仅"单字符键入 '@'"开启会话(粘贴不触发);
  /// 会话期间光标必须停在 '@' 之后、中间无空白,否则结束会话。
  /// 在 onTextChanged 中调用,依赖 _lastText 是变化前的文本。
  void _updateMentionSession(String text) {
    final TextSelection selection = textEditingController.selection;
    final int cursor = selection.isValid && selection.isCollapsed ? selection.start : -1;

    if (text.length == _lastText.length + 1 && cursor > 0 && text[cursor - 1] == '@') {
      // 确认是在光标处插入了单个 '@'(排除等长度的其他变化)
      if (text.substring(0, cursor - 1) + text.substring(cursor) == _lastText) {
        _mentionAtIndex = cursor - 1;
        _mentionQuery = '';
        onMentionTriggered?.call(conversation);
        return;
      }
    }

    if (_mentionAtIndex < 0) {
      return;
    }
    if (cursor <= _mentionAtIndex || _mentionAtIndex >= text.length || text[_mentionAtIndex] != '@') {
      _endMentionSession();
      return;
    }
    final String query = text.substring(_mentionAtIndex + 1, cursor);
    if (query.contains(RegExp(r'\s'))) {
      _endMentionSession();
      return;
    }
    _mentionQuery = query;
  }

  /// 纯光标移动(文本未变)时,光标离开查询串尾部即结束会话(微信:点击别处关闭浮层)。
  /// 失焦时不结束:移动端 @ 后跳选人页会失焦,会话要保留到选人返回。
  void _onEditingValueChanged() {
    if (_mentionAtIndex < 0 || textEditingController.text != _lastText || !focusNode.hasFocus) {
      return;
    }
    final TextSelection selection = textEditingController.selection;
    final int expected = _mentionAtIndex + 1 + _mentionQuery.length;
    if (!selection.isValid || !selection.isCollapsed || selection.start != expected) {
      _endMentionSession();
      notifyListeners();
    }
  }

  void _endMentionSession() {
    _mentionAtIndex = -1;
    _mentionQuery = '';
  }

  /// 取消当前 @ 会话(Esc、切换会话等),已输入的文本保持原样。
  void cancelMentionSession() {
    if (_mentionAtIndex < 0) {
      return;
    }
    _endMentionSession();
    notifyListeners();
  }

  /// 用选中的用户完成当前 @ 会话:把 "@查询串" 替换为 "@显示名 " 并登记 mention。
  void completeMention(UserInfo user) {
    if (_mentionAtIndex < 0) {
      return;
    }
    _isInsertingMention = true;

    final String name = MeshUserDisplay.getReadableName(user);
    final String text = textEditingController.text;
    final int replaceEnd = (_mentionAtIndex + 1 + _mentionQuery.length).clamp(0, text.length);
    final String textToInsert = '@$name ';
    final String newText = text.replaceRange(_mentionAtIndex, replaceEnd, textToInsert);

    // 替换区间长度变化,平移其后已登记的 mention
    final int shift = textToInsert.length - (replaceEnd - _mentionAtIndex);
    for (var mention in _mentionsList) {
      if (mention.start >= replaceEnd) {
        mention.start += shift;
        mention.end += shift;
      }
    }
    final int newCursorPos = _mentionAtIndex + textToInsert.length;
    _mentionsList.add(Mention(user.userId, name, _mentionAtIndex, newCursorPos - 1)); // -1 排除末尾空格

    _lastText = newText;
    _endMentionSession();
    textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      _isInsertingMention = false;
    });
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
    // 有进行中的 @ 会话(正常路径)直接复用;下面的旧逻辑只兜底
    // "会话已丢失但光标仍紧跟 '@'"的场景。
    if (_mentionAtIndex >= 0) {
      completeMention(user);
      return;
    }
    _isInsertingMention = true;

    final String name = user.displayName ?? user.userId;
    final TextEditingValue currentVal = textEditingController.value;
    final String currentText = currentVal.text;
    final int selectionStart = currentVal.selection.start;

    final int atSignIndex = selectionStart - 1;
    if (atSignIndex < 0 || atSignIndex >= currentText.length || currentText[atSignIndex] != '@') {
      _isInsertingMention = false;
      return;
    }

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

  void insertMention(UserInfo user) {
    _endMentionSession();
    _isInsertingMention = true;
    final String name = user.displayName ?? user.userId;
    final TextEditingValue currentVal = textEditingController.value;
    final String currentText = currentVal.text;

    int insertPos = currentVal.selection.start;
    if (insertPos < 0) {
      insertPos = currentText.length;
    }

    final String textToInsert = "@$name ";
    final String newText = currentText.replaceRange(insertPos, insertPos, textToInsert);

    // Shift existing mentions
    if (_mentionsList.isNotEmpty) {
      _handleMentionsChange(newText);
    }

    final int newCursorPos = insertPos + textToInsert.length;
    textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(TextPosition(offset: newCursorPos)),
    );

    _lastText = newText;
    final mentionEnd = newCursorPos - 1; // -1 to exclude the trailing space
    _mentionsList.add(Mention(user.userId, name, insertPos, mentionEnd));

    Future.delayed(const Duration(milliseconds: 150), () {
      _isInsertingMention = false;
    });
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    notifyListeners();
  }

  void _sendTextMessage(Conversation conversation, String text) async {
    TextMessageContent txt = TextMessageContent(text);
    if (_quoteInfo != null) {
      txt.quoteInfo = _quoteInfo;
    }
    List<String> mentionedUsers = _mentionsList.map((e) => e.userId).toList();
    if (mentionedUsers.isNotEmpty) {
      if (mentionedUsers.contains('@all')) {
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
    // 12 秒节流;时间戳统一用毫秒(此前 second 与 microsecondsSinceEpoch 量纲不匹配,整个会话只会发一次)
    if (DateTime.now().millisecondsSinceEpoch - _sendTypingTime > 12000 && text.isNotEmpty) {
      _sendTypingTime = DateTime.now().millisecondsSinceEpoch;
      TypingMessageContent typingMessageContent = TypingMessageContent();
      typingMessageContent.type = TypingType.Typing_TEXT;

      conversationViewModel.sendMessage(typingMessageContent);
    }
  }

  /// 3 秒无输入后自动保存草稿，对齐 iOS WFCUChatInputBar 行为。
  void _scheduleSaveDraft() {
    _saveDraftTimer?.cancel();
    _saveDraftTimer = Timer(const Duration(seconds: 3), _autoSaveDraft);
  }

  void _autoSaveDraft() {
    final draft = getDraft();
    if (draft != _conversationDraft) {
      Imclient.setConversationDraft(conversation, draft);
      _conversationDraft = draft;
    }
  }

  String getDraft() {
    // 草稿暂不支持附件:剔除内联附件占位符,只保存文本
    final String raw = textEditingController.text;
    final String content = raw.replaceAll(_inlineAttachmentPlaceholder, '');
    if (_mentionsList.isEmpty && _quoteInfo == null) {
      return content;
    }
    final draft = DraftData(content: content);
    draft.mentions = _mentionsList.map((m) {
      // 占位符被剔除后文本变短,mention 下标要减去其前方的占位符数
      // (占位符不可能落在 mention 内部,start/end 平移量相同)
      final int shift = _countInlineAttachmentPlaceholders(raw.substring(0, math.min(m.start, raw.length)));
      return DraftMention(
        uid: m.userId,
        isMentionAll: m.userId == '@all',
        start: m.start - shift,
        end: m.end - shift,
        displayName: m.displayName,
      );
    }).toList();
    draft.quoteInfo = _quoteInfo;
    return draft.toDraftString();
  }

  String getDraftDisplayText() {
    return DraftData.displayText(getDraft());
  }

  void setDraft(String draft) {
    _endMentionSession();
    _mentionsList.clear();
    // 整段替换文本,占位符随之消失,对应的内联附件一并丢弃
    _inlineAttachments.clear();
    _quotedMessage = null;
    _quoteInfo = null;

    final data = DraftData.fromDraftString(draft);
    textEditingController.text = data.content;
    textEditingController.selection = TextSelection(baseOffset: data.content.length, extentOffset: data.content.length);
    _lastText = data.content;
    _conversationDraft = draft;

    for (final m in data.mentions) {
      _mentionsList.add(Mention(
        m.uid,
        m.displayName ?? m.uid,
        m.start,
        m.end,
      ));
    }
    if (data.quoteInfo != null) {
      _quoteInfo = data.quoteInfo;
    }
    notifyListeners();
  }

  void insertText(String text) {
    final currentText = textEditingController.text;
    var selection = textEditingController.selection;
    if (selection.start < 0) {
      selection = TextSelection.collapsed(offset: currentText.length);
    }

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
    _scheduleSaveDraft();

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
    _saveDraftTimer?.cancel();
    _draftUpdatedSubscription?.cancel();
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

/// 输入框的富文本渲染控制器:emoji 适当放大,内联附件占位符(U+FFFC)渲染为
/// 图片/文件卡片 WidgetSpan(微信 PC 的粘贴图片/文件交互)。
///
/// 本引擎(ohos fork)有两个已实测的怪癖,渲染方案围绕它们设计,回归用例见
/// test/inline_image_input_test.dart:
/// 1. TextField 默认 strut 强制行高,任何行内内容都撑不开行框——使用方必须
///    传 strutStyle: StrutStyle.disabled,并配合 aboveBaseline 对齐
///    (top/middle/bottom 不参与行高计算);
/// 2. 尾随换行的"幻影末行"会整行复制上一行行高——见 [_needsTrailingLineAnchor]。
class EmojiTextEditingController extends TextEditingController {
  EmojiTextEditingController({super.text});

  /// 内联附件解析:第 ordinal 个占位符对应的附件(图片或文件),null 表示无对应附件。
  /// 由 [MessageInputBarController] 绑定到它的内联附件列表。
  InlineAttachment? Function(int ordinal)? inlineAttachmentResolver;

  /// 内联图片的最大显示高度(逻辑像素)。图片按原始尺寸显示,超过则等比缩小。
  /// PC 输入栏用 LayoutBuilder 按可见输入区高度实时更新,保证粘贴后不出滚动条。
  double inlineImageMaxHeight = 80;

  // buildTextSpan 期间的占位符游标,跨 before/composing/after 三段连续计数
  int _inlineAttachmentOrdinal = 0;

  // Regular expression to match emojis (covers standard emojis, emoticons, symbols, flag sequences, etc.)
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}]|[\u{1F000}-\u{1F0FF}]|[\u{1F1E6}-\u{1F1FF}]|[\u{2600}-\u{27BF}]|[\u{2300}-\u{23FF}]|[\u{2B50}]',
    unicode: true,
  );

  /// ZWSP 锚点会让"点击文本末尾之后"的命中测试返回 text.length+1 的越界位置,
  /// 所有编辑都走 value setter,在这里统一夹回文本末尾。
  @override
  set value(TextEditingValue newValue) {
    if (newValue.selection.isValid &&
        (newValue.selection.start > newValue.text.length || newValue.selection.end > newValue.text.length)) {
      newValue = newValue.copyWith(
        selection: TextSelection.collapsed(offset: newValue.text.length),
      );
    }
    super.value = newValue;
  }

  /// 文本以换行结尾且末行含图片时,引擎的"幻影末行"会复制图片行的行高
  /// (回车后出现图片一样高的空行)。追加一个零宽空格锚点让它自己形成正常行高的
  /// 末行,幻影行随之消失。锚点不存在于真实文本中,越界光标由 value setter 兜底。
  bool _needsTrailingLineAnchor(String text) {
    if (!text.endsWith('\n')) {
      return false;
    }
    final int prevBreak = text.lastIndexOf('\n', text.length - 2);
    final String lastLine = text.substring(prevBreak + 1, text.length - 1);
    return lastLine.contains(_inlineAttachmentPlaceholder);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(!value.composing.isValid || !withComposing || value.composing.isCollapsed || (value.composing.start >= 0 && value.composing.end <= value.text.length));

    _inlineAttachmentOrdinal = 0;
    final bool hasComposing = value.composing.isValid && withComposing && !value.composing.isCollapsed;

    final List<InlineSpan> children;
    if (!hasComposing) {
      children = <InlineSpan>[_buildEmojiTextSpan(context, text, style)];
    } else {
      final TextStyle composingStyle = style?.merge(const TextStyle(decoration: TextDecoration.underline))
          ?? const TextStyle(decoration: TextDecoration.underline);

      final String beforeText = value.text.substring(0, value.composing.start);
      final String composingText = value.text.substring(value.composing.start, value.composing.end);
      final String afterText = value.text.substring(value.composing.end);

      children = <InlineSpan>[
        _buildEmojiTextSpan(context, beforeText, style),
        _buildEmojiTextSpan(context, composingText, composingStyle),
        _buildEmojiTextSpan(context, afterText, style),
      ];
    }
    if (_needsTrailingLineAnchor(value.text)) {
      children.add(const TextSpan(text: '\u200B')); // 幻影末行锚点,见 _needsTrailingLineAnchor
    }
    return TextSpan(style: style, children: children);
  }

  /// 先按内联附件占位符切段:占位符渲染为图片/文件卡片 WidgetSpan,其余文本做
  /// emoji 处理。占位符与 WidgetSpan 一一对应(各占 1 个字符位),保证光标/选区
  /// 位置映射不乱。
  TextSpan _buildEmojiTextSpan(BuildContext context, String text, TextStyle? style) {
    final List<InlineSpan> children = [];
    int runStart = 0;
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0xFFFC) {
        if (i > runStart) {
          _appendEmojiRuns(text.substring(runStart, i), style, children);
        }
        children.add(_buildInlineAttachmentSpan(context, style));
        runStart = i + 1;
      }
    }
    if (runStart < text.length) {
      _appendEmojiRuns(text.substring(runStart), style, children);
    }
    return TextSpan(style: style, children: children);
  }

  InlineSpan _buildInlineAttachmentSpan(BuildContext context, TextStyle? style) {
    final InlineAttachment? attachment = inlineAttachmentResolver?.call(_inlineAttachmentOrdinal++);
    if (attachment == null) {
      // 没有对应附件(不应出现):原样保留占位字符,维持文本与 span 的长度一致
      return TextSpan(text: _inlineAttachmentPlaceholder, style: style);
    }
    // aboveBaseline:附件底边坐在文字基线上,行高(ascent)随附件增长,
    // 后续文字与附件底部对齐(微信 PC 表现)。
    // 注意 top/middle/bottom 三种对齐都不参与行高计算,超高部分会溢出行框、
    // 盖住其他行/工具条,不要改回去(见 test/inline_image_input_test.dart)。
    return WidgetSpan(
      style: style,
      alignment: PlaceholderAlignment.aboveBaseline,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: attachment.isFile ? _buildInlineFileCard(context, attachment) : _buildInlineImage(attachment),
      ),
    );
  }

  Widget _buildInlineImage(InlineAttachment attachment) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ConstrainedBox(
        // 高度上限动态跟随输入区;宽度由文本段落宽度约束,600 只是兜底
        constraints: BoxConstraints(maxWidth: 600, maxHeight: inlineImageMaxHeight),
        child: Image.file(
          File(attachment.path),
          fit: BoxFit.contain,
          // 解码高度固定上限,避免拖拽调高度时反复重新解码;不放大小图
          cacheHeight: 800,
          errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
        ),
      ),
    );
  }

  /// 文件卡片:类型图标 + 文件名 + 大小,样式对齐文件消息气泡
  /// (微信 PC:粘贴的文件以卡片显示在输入框里,发送时发文件消息)。
  Widget _buildInlineFileCard(BuildContext context, InlineAttachment attachment) {
    final colors = context.colors;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.hairline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/file_type/${Utilities.fileType(attachment.fileName!)}.png',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sm.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  Utilities.formatSize(attachment.fileSize),
                  style: AppText.xs.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _appendEmojiRuns(String text, TextStyle? style, List<InlineSpan> children) {
    final baseFontSize = style?.fontSize ?? 16.0;
    // Scale emoji font size to make them look comparable to or slightly larger than text.
    final emojiStyle = style?.copyWith(
      fontSize: baseFontSize * 1.35,
    ) ?? TextStyle(fontSize: baseFontSize * 1.35);

    text.splitMapJoin(
      _emojiRegex,
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match.group(0),
          style: emojiStyle,
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          children.add(TextSpan(
            text: nonMatch,
            style: style,
          ));
        }
        return '';
      },
    );
  }
}
