import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
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
  late StreamSubscription<SendMessageSuccessEvent> _sendMessageSuccessSubscription;
  late StreamSubscription<SendMessageFailureEvent> _sendMessageFailureSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;
  late StreamSubscription<ConversationDraftUpdatedEvent> _draftUpdatedSubscription;

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
  String? _conversationTypingStatus;

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
    _conversationTypingStatus = null;
    _typingUserTime.clear();
    _isMultiSelectMode = false;
    _selectedMessageIds.clear();
    notifyListeners();
  }

  bool get noMoreNewerMsg => _noMoreNewerMsg;

  /// 本地与远端历史消息都已取尽。桌面端滚动到顶自动加载时用它终止请求。
  bool get noMoreHistoryMsg => _noMoreLocalHistoryMsg && _noMoreRemoteHistoryMsg;

  String get draft => _draft;

  int get unreadMessageCount {
    return 0;
  }

  String? get conversationTypingStatus {
    return _conversationTypingStatus;
  }

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
    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      // 定位到某条消息时，如果还没加载到最后，就不将新收到的消息加入到列表
      if (_currentConversation == null || !_noMoreNewerMsg) {
        return;
      }
      var newMsg = false;
      var messages = event.messages;
      if(_currentConversation!.conversationType == ConversationType.Chatroom) {
        messages = event.messages.reversed.toList();
      }
      for (Message msg in messages) {
        if (msg.conversation == _currentConversation) {
          if (msg.messageId == 0) {
            if (msg.content is TypingMessageContent) {
              _typingUserTime[msg.fromUser] = DateTime.now().millisecondsSinceEpoch;
              _startTypingTimer();
              debugPrint('typing');
            } else if (msg.content is StreamingTextGeneratingMessageContent) {
              var content = msg.content as StreamingTextGeneratingMessageContent;
              var index = _conversationMessageList.indexWhere((element) {
                if (element.message.content is StreamingTextGeneratingMessageContent) {
                  return (element.message.content as StreamingTextGeneratingMessageContent).streamId == content.streamId;
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
            if(msg.content.meta.type == 80){
              // recall
              // do nothing
              return;
            }
            _typingUserTime.remove(msg.fromUser);
            if (msg.content is StreamingTextGeneratedMessageContent) {
              var content = msg.content as StreamingTextGeneratedMessageContent;
              var index = _conversationMessageList.indexWhere((element) {
                if (element.message.content is StreamingTextGeneratingMessageContent) {
                  return (element.message.content as StreamingTextGeneratingMessageContent).streamId == content.streamId;
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
    _recallMessageSubscription = _eventBus.on<RecallMessageEvent>().listen((event) async {
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
    _messageUpdatedSubscription = _eventBus.on<MessageUpdatedEvent>().listen((event) async {
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
    _deleteMessageSubscription = _eventBus.on<DeleteMessageEvent>().listen((event) {
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
    _sendMessageStartSubscription = _eventBus.on<SendMessageStartEvent>().listen((event) {
      var msg = event.message;
      if(msg.messageId == 0) {
        return;
      }
      if (_currentConversation == msg.conversation) {
        // 使用 message.messageId 作为 key 去重,防止重复插入
        final existingIndex = _conversationMessageList.indexWhere(
            (uiMsg) => uiMsg.message.messageId == msg.messageId);
        if (existingIndex == -1) {
          _conversationMessageList.insert(0, UIMessage(msg));
          notifyListeners();
        }
      }
    });
    _sendMessageSuccessSubscription = _eventBus.on<SendMessageSuccessEvent>().listen((event) {
      _updateMessageSendStatusAndNotify(event.messageId, MessageStatus.Message_Status_Sent, event.messageUid, event.timestamp);
    });
    _sendMessageFailureSubscription = _eventBus.on<SendMessageFailureEvent>().listen((event) {
      _updateMessageSendStatusAndNotify(event.messageId, MessageStatus.Message_Status_Send_Failure);
    });
    _clearMessagesSubscription = _eventBus.on<ClearMessagesEvent>().listen((event) {
      if (event.conversation == _currentConversation) {
        _conversationMessageList.clear();
        notifyListeners();
      }
    });
    _draftUpdatedSubscription = _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      _draft = event.draft;
      notifyListeners();
    });
  }

  void setConversation(Conversation? conversation, {int? toFocusMessageId, Function(int err)? joinChatroomErrorCallback}) async {
    _noMoreRemoteHistoryMsg = false;
    _conversationMessageList = [];
    focusMessageIndex = 0;
    _conversationTypingStatus = null;
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
        _isHiddenConversationMemberName = await Imclient.isHiddenGroupMemberName(conversation.target);
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
          _conversationMessageList = messages.map((message) => UIMessage(message)).toList();
          if (messages.length < 20) {
            _noMoreLocalHistoryMsg = true;
          }
          notifyListeners();
        });
      }
    }
  }

  void _loadMessagesAround(int messageId) async {
    var targetMsg = await Imclient.getMessage(messageId);
    if (targetMsg == null) {
      _noMoreNewerMsg = true;
      Imclient.getMessages(_currentConversation!, 0, 20).then((messages) {
        _conversationMessageList = messages
            .where((message) => message.messageId != 0)
            .map((message) => UIMessage(message))
            .toList();
        if (messages.length < 20) {
          _noMoreLocalHistoryMsg = true;
        }
        notifyListeners();
      });
      return;
    }

    var olderMsgs = await Imclient.getMessages(_currentConversation!, messageId, 20);
    var newerMsgs = await Imclient.getMessages(_currentConversation!, messageId, -20);

    List<UIMessage> list = [];
    list.addAll(olderMsgs.reversed
        .where((msg) => msg.messageId != 0)
        .toList()
        .map((e) => UIMessage(e)));
    var uiTarget = UIMessage(targetMsg);
    uiTarget.highlighted = true;
    list.add(uiTarget);
    list.addAll(newerMsgs.reversed
        .where((msg) => msg.messageId != 0)
        .toList()
        .map((e) => UIMessage(e)));

    // 因为 _conversationMessageList 是反的，最新的在最前面
    _conversationMessageList = list.reversed.toList();
    focusMessageIndex = newerMsgs.length;
    if (olderMsgs.length < 20) {
      _noMoreLocalHistoryMsg = true;
    }
    if (newerMsgs.length < 20) {
      _noMoreNewerMsg = true;
    }
    notifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      uiTarget.highlighted = false;
      notifyListeners();
    });
  }

  Future<void> loadNewerMessage() {
    if (_isLoading || _noMoreNewerMsg) {
      return Future.value();
    }
    Completer<void> completer = Completer();

    _isLoading = true;
    int fromIndex = _conversationMessageList.isEmpty ? 0 : _conversationMessageList.first.message.messageId;

    Imclient.getMessages(_currentConversation!, fromIndex, -20).then((messages) {
      _isLoading = false;
      if (messages.isEmpty) {
        _noMoreNewerMsg = true;
        notifyListeners();
        completer.complete();
        return;
      }
      var newMsgs = messages.where((msg) => msg.messageId != 0).map((msg) => UIMessage(msg)).toList();
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

  _updateMessageSendStatusAndNotify(int msgId, MessageStatus status, [int msgUid = 0, int timestamp = 0]) {
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
    var newMsgs = msgs.where((msg) => msg.messageId != 0).toList();
    if (newMsgs.isEmpty) {
      return;
    }
    // 按时间倒序排列，确保消息列表顺序正确（远端拉取回来的顺序不一定可靠）
    newMsgs.sort((a, b) {
      int timeCompare = b.serverTime.compareTo(a.serverTime);
      if (timeCompare != 0) return timeCompare;
      return b.messageId.compareTo(a.messageId);
    });
    _conversationMessageList.insertAll(index, newMsgs.map((msg) => UIMessage(msg)));
    notifyListeners();
  }

  Future<void> loadHistoryMessage() {
    if (_isLoading) {
      return Future.value();
    }
    Completer<void> completer = Completer();

    _isLoading = true;
    int? fromIndex = 0;

    var loadingConv = _currentConversation!;
    if (_noMoreLocalHistoryMsg) {
      if (_noMoreRemoteHistoryMsg) {
        _isLoading = false;
        completer.complete();
        return completer.future;
      } else {
        fromIndex = _conversationMessageList.isEmpty ? 0 : _conversationMessageList.last.message.messageUid;
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
      fromIndex = _conversationMessageList.isEmpty ? 0 : _conversationMessageList.last.message.messageId;
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

  void sendMediaMessage(MessageContent messageContent, {Function(String remoteUrl)? uploadedCallback}) {
    if (_currentConversation == null) {
      return;
    }
    Imclient.sendMediaMessage(_currentConversation!, messageContent,
        successCallback: (int messageUid, int timestamp) {},
        errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
          debugPrint("progressCallback:$uploaded,$total");
        },
        uploadedCallback: (String remoteUrl) {
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
        _conversationTypingStatus = '对方正在输入${_getTypingDot(now)}';
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
        _conversationTypingStatus = '$typingUserCount人正在输入${_getTypingDot(now)}';
        return true;
      } else if (typingUserCount == 1) {
        Imclient.getUserInfo(lastTypingUser!, groupId: _currentConversation!.target).then((value) {
          if (value != null) {
            _conversationTypingStatus = '${value.displayName!} 正在输入${_getTypingDot(now)}';
          }
        });
        return true;
      }
    }

    _conversationTypingStatus = null;
    return false;
  }

  void _startTypingTimer() {
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
  }
}
