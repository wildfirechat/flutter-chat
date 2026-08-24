import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/streaming_text_cancelled_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:chat/ui_model/ui_message.dart';

class ConversationViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<MessageUpdatedEvent> _messageUpdatedSubscription;
  late StreamSubscription<DeleteMessageEvent> _deleteMessageSubscription;
  late StreamSubscription<SendMessageStartEvent> _sendMessageStartSubscription;
  late StreamSubscription<SendMessageSuccessEvent>
      _sendMessageSuccessSubscription;
  late StreamSubscription<SendMessageFailureEvent>
      _sendMessageFailureSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;
  late StreamSubscription<ConversationDraftUpdatedEvent>
      _draftUpdatedSubscription;

  //  消息倒序，第 0 条是最新消息，但UI 层list 进行了 reverse
  List<UIMessage> _conversationMessageList = [];
  Conversation? _currentConversation;
  ConversationInfo? _currentConversationInfo;
  late String _draft;
  bool _isHiddenConversationMemberName = false;
  bool _isLoading = false;
  bool _noMoreLocalHistoryMsg = false;
  bool _noMoreRemoteHistoryMsg = false;
  bool _noMoreNewerMsg = false;
  int focusMessageIndex = 0;

  /// 0 = 无人输入；1 = 单聊对方；2 = 群内多人；3 = 群内单个具名用户
  int _typingKind = 0;
  int _typingCount = 0;
  String? _typingUserName;
  String _typingDots = '';

  /// 定位到历史消息后（还没加载回最新）期间新收到的消息数，
  /// 用于「回到最新」按钮上的角标；回到最新或重新进入会话时清零。
  int _pendingNewMessageCount = 0;
  int get pendingNewMessageCount => _pendingNewMessageCount;

  Timer? _typingTimer;
  final Map<String, int> _typingUserTime = {};

  List<UIMessage> get conversationMessageList => _conversationMessageList;

  void reset() {
    _conversationMessageList = [];
    _currentConversation = null;
    _currentConversationInfo = null;
    _draft = '';
    _isHiddenConversationMemberName = false;
    _isLoading = false;
    _noMoreLocalHistoryMsg = false;
    _noMoreRemoteHistoryMsg = false;
    _noMoreNewerMsg = false;
    focusMessageIndex = 0;
    _typingKind = 0;
    _typingUserTime.clear();
    _isMultiSelectMode = false;
    _selectedMessageIds.clear();
    notifyListeners();
  }

  bool get noMoreNewerMsg => _noMoreNewerMsg;

  /// 本地与远端历史消息都已取尽。桌面端滚动到顶自动加载时用它终止请求。
  bool get noMoreHistoryMsg =>
      _noMoreLocalHistoryMsg && _noMoreRemoteHistoryMsg;

  String get draft => _draft;

  int get unreadMessageCount {
    return 0;
  }

  int get typingKind => _typingKind;
  int get typingCount => _typingCount;
  String? get typingUserName => _typingUserName;
  String get typingDots => _typingDots;

  bool get isHiddenConversationMemberName {
    return _isHiddenConversationMemberName;
  }

  ConversationInfo? get conversationInfo {
    return _currentConversationInfo;
  }

  /// 当前正在展示的会话。桌面端切换会话时,新会话页的 initState 先于旧会话页的
  /// dispose 执行,旧页面 dispose 前需要据此判断自己是否仍是当前会话,避免误清。
  Conversation? get currentConversation => _currentConversation;

  bool _isMultiSelectMode = false;
  final Set<int> _selectedMessageIds = {};

  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<int> get selectedMessageIds => _selectedMessageIds;

  void toggleMultiSelectMode() {
    _isMultiSelectMode = !_isMultiSelectMode;
    if (!_isMultiSelectMode) {
      _selectedMessageIds.clear();
    }
    notifyListeners();
  }

  void toggleMessageSelection(int messageId) {
    if (_selectedMessageIds.contains(messageId)) {
      _selectedMessageIds.remove(messageId);
    } else {
      _selectedMessageIds.add(messageId);
    }
    notifyListeners();
  }

  bool isMessageSelected(int messageId) {
    return _selectedMessageIds.contains(messageId);
  }

  List<Message> getSelectedMessages() {
    List<Message> selected = [];
    // Iterate through the list to maintain order (assuming list is ordered)
    // Note: _conversationMessageList is reversed (0 is newest).
    // If we want chronological order, we should iterate from end to start.
    for (int i = _conversationMessageList.length - 1; i >= 0; i--) {
      var msg = _conversationMessageList[i].message;
      if (_selectedMessageIds.contains(msg.messageId)) {
        selected.add(msg);
      }
    }
    return selected;
  }

  ConversationViewModel() {
    _receiveMessageSubscription =
        _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      // 定位到某条消息时，如果还没加载到最后，就不将新收到的消息加入到列表，
      // 只统计数量用于「回到最新」按钮角标（消息本身已入本地库，回到最新时会带出）
      if (_currentConversation != null && !_noMoreNewerMsg) {
        var count = 0;
        for (final msg in event.messages) {
          if (msg.conversation == _currentConversation &&
              msg.messageId != 0 &&
              msg.content is! TypingMessageContent &&
              msg.content.meta.type != 80) {
            count++;
          }
        }
        if (count > 0) {
          _pendingNewMessageCount += count;
          notifyListeners();
        }
        return;
      }
      if (_currentConversation == null) {
        return;
      }
      var newMsg = false;
      var messages = event.messages;
      if (_currentConversation!.conversationType == ConversationType.Chatroom) {
        messages = event.messages.reversed.toList();
      }
      for (Message msg in messages) {
        if (msg.conversation == _currentConversation) {
          // 流式文本取消消息(20)：按 streamId 从消息列表删除对应的
          // generating(14)/generated(15) 消息（"生成中"气泡直接消失），
          // 取消消息自身不进入列表（Transparent，不落库）
          if (msg.content is StreamingTextCancelledMessageContent) {
            var content = msg.content as StreamingTextCancelledMessageContent;
            var index = _conversationMessageList.indexWhere((element) {
              final c = element.message.content;
              if (c is StreamingTextGeneratingMessageContent) {
                return c.streamId == content.streamId;
              }
              if (c is StreamingTextGeneratedMessageContent) {
                return c.streamId == content.streamId;
              }
              return false;
            });
            if (index != -1) {
              _conversationMessageList.removeAt(index);
              newMsg = true;
            }
            continue;
          }
          if (msg.messageId == 0) {
            if (msg.content is TypingMessageContent) {
              _typingUserTime[msg.fromUser] =
                  DateTime.now().millisecondsSinceEpoch;
              _startTypingTimer();
              debugPrint('typing');
            } else if (msg.content is StreamingTextGeneratingMessageContent) {
              var content =
                  msg.content as StreamingTextGeneratingMessageContent;
              var index = _conversationMessageList.indexWhere((element) {
                if (element.message.content
                    is StreamingTextGeneratingMessageContent) {
                  return (element.message.content
                              as StreamingTextGeneratingMessageContent)
                          .streamId ==
                      content.streamId;
                }
                return false;
              });
              if (index != -1) {
                _conversationMessageList[index] = UIMessage(msg);
                newMsg = true;
              } else {
                _conversationMessageList.insert(0, UIMessage(msg));
                newMsg = true;
              }
            }
          } else {
            if (msg.content.meta.type == 80) {
              // recall
              // do nothing
              return;
            }
            _typingUserTime.remove(msg.fromUser);
            if (msg.content is StreamingTextGeneratedMessageContent) {
              var content = msg.content as StreamingTextGeneratedMessageContent;
              var index = _conversationMessageList.indexWhere((element) {
                if (element.message.content
                    is StreamingTextGeneratingMessageContent) {
                  return (element.message.content
                              as StreamingTextGeneratingMessageContent)
                          .streamId ==
                      content.streamId;
                }
                return false;
              });
              if (index != -1) {
                _conversationMessageList[index] = UIMessage(msg);
                newMsg = true;
                continue;
              }
            }
            _conversationMessageList.insert(0, UIMessage(msg));
            newMsg = true;
          }
        }
      }
      // newMsg ? notifyListeners() : null;
      if (newMsg) {
        Imclient.clearConversationUnreadStatus(_currentConversation!);
        notifyListeners();
      }
    });
    _recallMessageSubscription =
        _eventBus.on<RecallMessageEvent>().listen((event) async {
      var msgUid = event.messageUid;
      for (var index = 0; index < _conversationMessageList.length; index++) {
        if (_conversationMessageList[index].message.messageUid == msgUid) {
          var msg = await Imclient.getMessageByUid(msgUid);
          if (msg != null) {
            _conversationMessageList[index] = UIMessage(msg);
            notifyListeners();
          }
          break;
        }
      }
    });
    _messageUpdatedSubscription =
        _eventBus.on<MessageUpdatedEvent>().listen((event) async {
      var msgId = event.messageId;
      for (var index = 0; index < _conversationMessageList.length; index++) {
        if (_conversationMessageList[index].message.messageId == msgId) {
          var msg = await Imclient.getMessage(msgId);
          if (msg != null) {
            _conversationMessageList[index] = UIMessage(msg);
            notifyListeners();
          }
          break;
        }
      }
    });
    _deleteMessageSubscription =
        _eventBus.on<DeleteMessageEvent>().listen((event) {
      var msgUid = event.messageUid;
      var msgId = event.messageId;
      if (msgUid != null) {
        for (UIMessage msg in _conversationMessageList) {
          if (msg.message.messageUid == msgUid) {
            _conversationMessageList.remove(msg);
            notifyListeners();
            return;
          }
        }
      }
      if (msgId != null) {
        for (UIMessage msg in _conversationMessageList) {
          if (msg.message.messageId == msgId) {
            _conversationMessageList.remove(msg);
            notifyListeners();
            return;
          }
        }
      }
    });
    _sendMessageStartSubscription =
        _eventBus.on<SendMessageStartEvent>().listen((event) {
      var msg = event.message;
      if (msg.messageId == 0) {
        return;
      }
      if (_currentConversation == msg.conversation) {
        // 使用 message.messageId 作为 key 去重,防止重复插入
        final existingIndex = _conversationMessageList
            .indexWhere((uiMsg) => uiMsg.message.messageId == msg.messageId);
        if (existingIndex == -1) {
          _conversationMessageList.insert(0, UIMessage(msg));
          notifyListeners();
        }
      }
    });
    _sendMessageSuccessSubscription =
        _eventBus.on<SendMessageSuccessEvent>().listen((event) {
      _updateMessageSendStatusAndNotify(event.messageId,
          MessageStatus.Message_Status_Sent, event.messageUid, event.timestamp);
    });
    _sendMessageFailureSubscription =
        _eventBus.on<SendMessageFailureEvent>().listen((event) {
      _updateMessageSendStatusAndNotify(
          event.messageId, MessageStatus.Message_Status_Send_Failure);
    });
    _clearMessagesSubscription =
        _eventBus.on<ClearMessagesEvent>().listen((event) {
      if (event.conversation == _currentConversation) {
        _conversationMessageList.clear();
        notifyListeners();
      }
    });
    _draftUpdatedSubscription =
        _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      _draft = event.draft;
      notifyListeners();
    });
  }

  /// 会话代际号：每次 setConversation（包括置 null）递增。
  /// 用于异步加载过程中的"是否已被新的 setConversation 取代"判断，
  /// 以及 ConversationPane dispose 时识别自己是不是当前会话的持有者。
  int _session = 0;
  int get conversationSession => _session;

  void setConversation(Conversation? conversation,
      {int? toFocusMessageId,
      Function(int err)? joinChatroomErrorCallback}) async {
    _session++;
    _noMoreRemoteHistoryMsg = false;
    _conversationMessageList = [];
    _pendingNewMessageCount = 0;
    focusMessageIndex = 0;
    _typingKind = 0;
    _currentConversation = conversation;
    _isMultiSelectMode = false;
    _stopTypingTimer();

    if (conversation == null) {
      _currentConversation = null;
      _currentConversationInfo = null;
      return;
    }

    _currentConversationInfo = await Imclient.getConversationInfo(conversation);
    // 进入会话时刷新 target 资料，对齐 iOS 行为
    _refreshTargetInfo(conversation);
    if (conversation.conversationType == ConversationType.Chatroom) {
      _noMoreLocalHistoryMsg = true;
      _noMoreNewerMsg = true;
      Imclient.joinChatroom(conversation.target, () {
        Imclient.getUserInfo(Imclient.currentUserId).then((userInfo) {
          if (userInfo != null) {
            TipNotificationContent tip = TipNotificationContent();
            tip.tip = '欢迎 ${userInfo.displayName} 加入聊天室';
            sendMessage(tip);
          }
        });
      }, (errorCode) {
        joinChatroomErrorCallback?.call(errorCode);
      });
    } else {
      if (conversation.conversationType == ConversationType.Group) {
        _isHiddenConversationMemberName =
            await Imclient.isHiddenGroupMemberName(conversation.target);
      } else {
        _isHiddenConversationMemberName = true;
      }
      _noMoreLocalHistoryMsg = false;
      _noMoreNewerMsg = false;

      if (toFocusMessageId != null && toFocusMessageId > 0) {
        _loadMessagesAround(toFocusMessageId);
      } else {
        _noMoreNewerMsg = true;
        Imclient.getMessages(conversation, 0, 20).then((messages) {
          // 加载历史时按 streamId 归一化去重：同 streamId 的多条「生成中(14)」
          // 只保留最新一条（或存在「已生成(15)」时全部丢弃），避免切换会话后
          // 重复显示多条"生成中"气泡，见 _prepareDisplayMessages
          _conversationMessageList = _prepareDisplayMessages(messages)
              .map((message) => UIMessage(message))
              .toList();
          if (messages.length < 20) {
            _noMoreLocalHistoryMsg = true;
          }
          notifyListeners();
        });
      }
    }
  }

  /// 回到最新：定位历史消息后调用，重新加载最新一页并清掉新消息角标。
  /// 滚动位置由调用方（面板）重置。
  void backToLatest() {
    final conversation = _currentConversation;
    if (conversation == null) return;
    _session++;
    final session = _session;
    _pendingNewMessageCount = 0;
    focusMessageIndex = 0;
    _noMoreLocalHistoryMsg = false;
    _noMoreNewerMsg = true;
    Imclient.getMessages(conversation, 0, 20).then((messages) {
      if (session != _session || _currentConversation != conversation) return;
      _conversationMessageList = _prepareDisplayMessages(messages)
          .map((message) => UIMessage(message))
          .toList();
      if (messages.length < 20) {
        _noMoreLocalHistoryMsg = true;
      }
      notifyListeners();
    });
  }

  void _loadMessagesAround(int messageId) async {
    // setConversation 是异步过程，期间可能被另一次 setConversation（含旧页面
    // dispose 置 null）打断，会话引用和代际号都要先快照，恢复执行时校验。
    final conversation = _currentConversation;
    if (conversation == null) return;
    final session = _session;
    bool stale() => session != _session || _currentConversation != conversation;

    var targetMsg = await Imclient.getMessage(messageId);
    if (stale()) return;
    if (targetMsg == null) {
      _noMoreNewerMsg = true;
      Imclient.getMessages(conversation, 0, 20).then((messages) {
        if (stale()) return;
        _conversationMessageList = _prepareDisplayMessages(messages)
            .map((message) => UIMessage(message))
            .toList();
        if (messages.length < 20) {
          _noMoreLocalHistoryMsg = true;
        }
        notifyListeners();
      });
      return;
    }

    var olderMsgs = await Imclient.getMessages(conversation, messageId, 20);
    var newerMsgs = await Imclient.getMessages(conversation, messageId, -20);
    if (stale()) return;

    // 时间正序合并 older/target/newer 后再统一做流式去重（对齐 HarmonyOS
    // setMessages(aroundMessages) 的一次归一化），覆盖三段内同 streamId 的重复
    final combined = <Message>[
      ...olderMsgs.reversed,
      targetMsg,
      ...newerMsgs.reversed,
    ];
    final normalized = _prepareDisplayMessages(combined);

    List<UIMessage> list = [];
    var targetIndex = -1;
    UIMessage? highlightedUi;
    for (var i = 0; i < normalized.length; i++) {
      final ui = UIMessage(normalized[i]);
      if (identical(normalized[i], targetMsg)) {
        ui.highlighted = true;
        highlightedUi = ui;
        targetIndex = i;
      }
      list.add(ui);
    }

    // 因为 _conversationMessageList 是反的，最新的在最前面
    _conversationMessageList = list.reversed.toList();
    if (targetIndex != -1) {
      // 正序下标换算成倒序列表中"目标之前（更新）"的消息数
      focusMessageIndex = normalized.length - 1 - targetIndex;
    } else {
      // 目标消息被去重（定位到的"生成中"已被同 streamId 的"已生成"取代），
      // 用原始分段数量近似，最终消息与目标相邻，滚动位置基本一致
      focusMessageIndex = newerMsgs.length;
    }
    if (olderMsgs.length < 20) {
      _noMoreLocalHistoryMsg = true;
    }
    if (newerMsgs.length < 20) {
      _noMoreNewerMsg = true;
    }
    notifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      if (stale()) return;
      highlightedUi?.highlighted = false;
      notifyListeners();
    });
  }

  Future<void> loadNewerMessage() {
    if (_isLoading || _noMoreNewerMsg) {
      return Future.value();
    }
    Completer<void> completer = Completer();

    _isLoading = true;
    int fromIndex = _conversationMessageList.isEmpty
        ? 0
        : _conversationMessageList.first.message.messageId;

    final loadingConv = _currentConversation;
    if (loadingConv == null) {
      _isLoading = false;
      completer.complete();
      return completer.future;
    }
    Imclient.getMessages(loadingConv, fromIndex, -20).then((messages) {
      _isLoading = false;
      if (loadingConv != _currentConversation) {
        completer.complete();
        return;
      }
      if (messages.isEmpty) {
        _noMoreNewerMsg = true;
        notifyListeners();
        completer.complete();
        return;
      }
      var newMsgs = _prepareDisplayMessages(messages)
          .map((msg) => UIMessage(msg))
          .toList();
      if (newMsgs.isEmpty) {
        _noMoreNewerMsg = true;
        notifyListeners();
        completer.complete();
        return;
      }
      _conversationMessageList.insertAll(0, newMsgs);
      focusMessageIndex += newMsgs.length;
      if (messages.length < 20) {
        _noMoreNewerMsg = true;
      }
      notifyListeners();
      completer.complete();
    });
    return completer.future;
  }

  setConversationSilent(Conversation conversation, bool silent) {
    Imclient.setConversationSilent(conversation, silent, () {
      if (conversation == _currentConversation) {
        _currentConversationInfo?.isSilent = silent;
        notifyListeners();
      }
    }, (errorCode) {
      // do nothing
    });
  }

  setConversationTop(Conversation conversation, int top) {
    Imclient.setConversationTop(conversation, top, () {
      if (conversation == _currentConversation) {
        _currentConversationInfo?.isTop = top;
        notifyListeners();
      }
    }, (errorCode) {
      // do nothing
    });
  }

  void setHideGroupMemberName(String groupId, bool hide) {
    Imclient.setHiddenGroupMemberName(groupId, hide, () {
      _isHiddenConversationMemberName = hide;
      notifyListeners();
    }, (errorCode) {});
  }

  _updateMessageSendStatusAndNotify(int msgId, MessageStatus status,
      [int msgUid = 0, int timestamp = 0]) {
    for (UIMessage msg in _conversationMessageList) {
      if (msg.message.messageId == msgId) {
        msg.message.messageUid = msgUid;
        msg.message.status = status;
        msg.message.serverTime = timestamp;
        notifyListeners();
        return;
      }
    }
  }

  deleteMessage(int messageId) async {
    var result = await Imclient.deleteMessage(messageId);
    if (result) {
      for (int i = 0; i < _conversationMessageList.length; i++) {
        if (_conversationMessageList[i].message.messageId == messageId) {
          _conversationMessageList.removeAt(i);
          notifyListeners();
          break;
        }
      }
    }
  }

  void _insertMessages(int index, List<Message> msgs) {
    var newMsgs = _prepareDisplayMessages(msgs);
    if (newMsgs.isEmpty) {
      return;
    }
    // 按时间倒序排列，确保消息列表顺序正确（远端拉取回来的顺序不一定可靠）
    newMsgs.sort((a, b) {
      int timeCompare = b.serverTime.compareTo(a.serverTime);
      if (timeCompare != 0) return timeCompare;
      return b.messageId.compareTo(a.messageId);
    });
    _conversationMessageList.insertAll(
        index, newMsgs.map((msg) => UIMessage(msg)));
    notifyListeners();
  }

  /// 把 DB/远端取回的消息整理成可展示列表（对齐 HarmonyOS isDisplayMessage +
  /// normalizeStreaming）：
  /// 1. 丢弃 messageId == 0 且非「生成中(14)」的消息（未落库的中间消息不展示，
  ///    与 HarmonyOS 一致：保留 messageId != 0 或生成中消息）；
  /// 2. 丢弃「已取消(20)」：Transparent 删除信号正常不落库，这里兜底防历史残留占位；
  /// 3. 流式消息(14/15)按 streamId 归一化去重，见 [_normalizeStreamingMessages]。
  List<Message> _prepareDisplayMessages(List<Message> messages) {
    final result = <Message>[];
    for (final msg in messages) {
      final content = msg.content;
      if (msg.messageId == 0 &&
          content is! StreamingTextGeneratingMessageContent) {
        continue;
      }
      if (content is StreamingTextCancelledMessageContent) {
        continue;
      }
      result.add(msg);
    }
    return _normalizeStreamingMessages(result);
  }

  /// 加载历史消息时对流式消息按 streamId 归一化去重，切换会话后不会重复显示多条
  /// 「生成中(14)」气泡（机器人逐字推送、每条都入库）。语义与 HarmonyOS 的
  /// normalizeStreaming 一致："组内最后一条" = 最新一条（文本最全）——
  /// HarmonyOS 列表为正序（旧→新）所以取末位下标；本列表为倒序（新→旧）且
  /// [_loadMessagesAround] 的合并段方向不定，统一按 (serverTime, messageId)
  /// 比较取最新，结果一致且不依赖列表方向：
  /// - 同 streamId 存在「已生成(15)」→ 丢弃组内所有「生成中(14)」，只保留最终结果；
  /// - 只有「生成中(14)」→ 只保留组内最新一条；
  /// - 非流式消息全部保留，相对顺序不变。
  List<Message> _normalizeStreamingMessages(List<Message> messages) {
    if (messages.isEmpty) {
      return messages;
    }
    // 第一遍：按 streamId 统计「已生成(15)」是否存在、该组最新一条「生成中(14)」
    final hasGenerated = <String, bool>{};
    final newestGenerating = <String, Message>{};
    for (final msg in messages) {
      final content = msg.content;
      if (content is StreamingTextGeneratedMessageContent) {
        final streamId = content.streamId;
        if (streamId.isEmpty) continue;
        hasGenerated[streamId] = true;
      } else if (content is StreamingTextGeneratingMessageContent) {
        final streamId = content.streamId;
        if (streamId.isEmpty) continue;
        final prev = newestGenerating[streamId];
        if (prev == null ||
            msg.serverTime > prev.serverTime ||
            (msg.serverTime == prev.serverTime &&
                msg.messageId > prev.messageId)) {
          newestGenerating[streamId] = msg;
        }
      }
    }
    if (hasGenerated.isEmpty && newestGenerating.isEmpty) {
      return messages;
    }
    // 第二遍：过滤重复的「生成中(14)」
    final result = <Message>[];
    for (final msg in messages) {
      final content = msg.content;
      if (content is StreamingTextGeneratingMessageContent) {
        final streamId = content.streamId;
        if (streamId.isNotEmpty &&
            (hasGenerated[streamId] == true ||
                !identical(newestGenerating[streamId], msg))) {
          continue;
        }
      }
      result.add(msg);
    }
    return result;
  }

  Future<void> loadHistoryMessage() {
    if (_isLoading) {
      return Future.value();
    }
    Completer<void> completer = Completer();

    _isLoading = true;
    int? fromIndex = 0;

    var loadingConv = _currentConversation;
    if (loadingConv == null) {
      _isLoading = false;
      completer.complete();
      return completer.future;
    }
    if (_noMoreLocalHistoryMsg) {
      if (_noMoreRemoteHistoryMsg) {
        _isLoading = false;
        completer.complete();
        return completer.future;
      } else {
        fromIndex = _conversationMessageList.isEmpty
            ? 0
            : _conversationMessageList.last.message.messageUid;
        Imclient.getRemoteMessages(loadingConv, fromIndex!, 20, (messages) {
          if (loadingConv != _currentConversation) {
            completer.complete();
            return;
          }
          if (messages.isEmpty) {
            _noMoreRemoteHistoryMsg = true;
          }
          _isLoading = false;
          if (messages.isNotEmpty) {
            _insertMessages(_conversationMessageList.length, messages);
          } else {
            notifyListeners();
          }
          completer.complete();
        }, (errorCode) {
          _isLoading = false;
          _noMoreRemoteHistoryMsg = true;
          notifyListeners();
          completer.complete();
        });
      }
    } else {
      fromIndex = _conversationMessageList.isEmpty
          ? 0
          : _conversationMessageList.last.message.messageId;
      Imclient.getMessages(loadingConv, fromIndex, 20).then((messages) {
        if (loadingConv != _currentConversation) {
          completer.complete();
          return;
        }
        _isLoading = false;
        if (messages.isEmpty) {
          _noMoreLocalHistoryMsg = true;
          notifyListeners();
          completer.complete();
          return;
        }
        _insertMessages(_conversationMessageList.length, messages);
        completer.complete();
      });
    }
    return completer.future;
  }

  void sendMediaMessage(MessageContent messageContent,
      {Function(String remoteUrl)? uploadedCallback}) {
    if (_currentConversation == null) {
      return;
    }
    Imclient.sendMediaMessage(_currentConversation!, messageContent,
        successCallback: (int messageUid, int timestamp) {},
        errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
      debugPrint("progressCallback:$uploaded,$total");
    }, uploadedCallback: (String remoteUrl) {
      debugPrint("uploadedCallback:$remoteUrl");
      uploadedCallback?.call(remoteUrl);
    });
  }

  void sendMessage(MessageContent messageContent) {
    if (_currentConversation == null) {
      return;
    }
    Imclient.sendMessage(_currentConversation!, messageContent,
        successCallback: (messageUid, timestamp) {},
        errorCallback: (errorCode) {});
  }

  String _getTypingDot(int time) {
    int dotCount = time ~/ 1000 % 4;
    String ret = '';
    for (int i = 0; i < dotCount; i++) {
      ret = '$ret.';
    }
    return ret;
  }

  bool _updateTypingStatus() {
    if (_currentConversation == null) {
      return false;
    }
    int now = DateTime.now().millisecondsSinceEpoch;
    if (_currentConversation!.conversationType == ConversationType.Single) {
      int? time = _typingUserTime[_currentConversation!.target];
      if (time != null && now - time < 6000) {
        _typingKind = 1;
        _typingCount = 0;
        _typingUserName = null;
        _typingDots = _getTypingDot(now);
        return true;
      }
    } else {
      int typingUserCount = 0;
      String? lastTypingUser;
      for (String userId in _typingUserTime.keys) {
        int time = _typingUserTime[userId]!;
        if (now - time < 6000) {
          typingUserCount++;
          lastTypingUser = userId;
        }
      }
      if (typingUserCount > 1) {
        _typingKind = 2;
        _typingCount = typingUserCount;
        _typingUserName = null;
        _typingDots = _getTypingDot(now);
        return true;
      } else if (typingUserCount == 1) {
        Imclient.getUserInfo(lastTypingUser!,
                groupId: _currentConversation!.target)
            .then((value) {
          if (value != null) {
            _typingKind = 3;
            _typingUserName = value.displayName;
            _typingDots = _getTypingDot(now);
          }
        });
        return true;
      }
    }

    _typingKind = 0;
    return false;
  }

  void _startTypingTimer() {
    // 先取消旧 timer，避免每次收到 TypingMessageContent 都新建一个孤儿定时器
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      bool isUserTyping = _updateTypingStatus();
      if (!isUserTyping && _typingUserTime.isNotEmpty) {
        _typingUserTime.clear();
        _stopTypingTimer();
      }
      notifyListeners();
    });
  }

  void _stopTypingTimer() {
    if (_typingTimer != null) {
      _typingTimer!.cancel();
      _typingTimer = null;
    }
  }

  /// 进入会话时刷新目标资料，让标题、头像等尽快拿到最新数据。
  /// 已进入会话并强制同步过资料的会话 key：控制每个会话只在首次进入时
  /// 同步一次，避免切会话/重建页面时反复打服务器。
  final Set<String> _refreshedTargetKeys = {};

  void _refreshTargetInfo(Conversation conversation) {
    final key =
        '${conversation.conversationType.index}-${conversation.target}-${conversation.line}';
    if (!_refreshedTargetKeys.add(key)) return;
    switch (conversation.conversationType) {
      case ConversationType.Single:
        Imclient.getUserInfo(conversation.target, refresh: true);
        break;
      case ConversationType.Group:
        Imclient.getGroupInfo(conversation.target, refresh: true);
        Imclient.getGroupMembers(conversation.target, refresh: true);
        break;
      case ConversationType.Channel:
        Imclient.getChannelInfo(conversation.target, refresh: true);
        break;
      case ConversationType.Chatroom:
      default:
        break;
    }
  }

  @override
  void notifyListeners() {
    if (_currentConversation != null) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _conversationMessageList.clear();
    _receiveMessageSubscription.cancel();
    _recallMessageSubscription.cancel();
    _messageUpdatedSubscription.cancel();
    _deleteMessageSubscription.cancel();
    _sendMessageStartSubscription.cancel();
    _clearMessagesSubscription.cancel();
    _draftUpdatedSubscription.cancel();
    _sendMessageSuccessSubscription.cancel();
    _sendMessageFailureSubscription.cancel();
    _stopTypingTimer();
  }
}
