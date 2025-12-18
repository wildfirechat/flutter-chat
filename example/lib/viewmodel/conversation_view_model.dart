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
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:intl/intl.dart';
import 'package:wfc_example/repo/user_repo.dart';
import 'package:wfc_example/ui_model/ui_message.dart';

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
  late Conversation? _currentConversation;
  late ConversationInfo? _currentConversationInfo;
  late String _draft;
  bool _isHiddenConversationMemberName = false;
  bool _isLoading = false;
  bool _noMoreLocalHistoryMsg = false;
  bool _noMoreRemoteHistoryMsg = false;
  String? _conversationTypingStatus;

  Timer? _typingTimer;
  final Map<String, int> _typingUserTime = {};

  List<UIMessage> get conversationMessageList => _conversationMessageList;

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
      if (_currentConversation == null) {
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
      if (_currentConversation == msg.conversation && msg.messageId != 0) {
        _conversationMessageList.insert(0, UIMessage(msg));
        notifyListeners();
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

  void setConversation(Conversation? conversation, {Function(int err)? joinChatroomErrorCallback}) async {
    _noMoreRemoteHistoryMsg = false;
    _conversationMessageList = [];
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
    if (conversation.conversationType == ConversationType.Chatroom) {
      _noMoreLocalHistoryMsg = true;
      Imclient.joinChatroom(conversation.target, () {
        Imclient.getUserInfo(Imclient.currentUserId).then((userInfo) {
          if (userInfo != null) {
            TipNotificationContent tip = TipNotificationContent();
            tip.tip = '欢迎 ${userInfo.displayName} 加入聊天室';
            _sendMessage(tip);
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
      Imclient.getMessages(conversation, 0, 20).then((messages) {
        _conversationMessageList = messages.map((message) => UIMessage(message)).toList();
        notifyListeners();
      });
    }
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
    var newMsgs = msgs.map((msg) => UIMessage(msg));
    _conversationMessageList.insertAll(index, newMsgs);
    notifyListeners();
  }

  void loadHistoryMessage() {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    int? fromIndex = 0;

    var loadingConv = _currentConversation!;
    if (_noMoreLocalHistoryMsg) {
      if (_noMoreRemoteHistoryMsg) {
        _isLoading = false;
        return;
      } else {
        fromIndex = _conversationMessageList.isEmpty ? 0 : _conversationMessageList.last.message.messageUid;
        Imclient.getRemoteMessages(loadingConv, fromIndex!, 20, (messages) {
          if (loadingConv != _currentConversation) {
            return;
          }
          if (messages.isEmpty) {
            _noMoreRemoteHistoryMsg = true;
          }
          _isLoading = false;
          if(messages.isNotEmpty){
            _insertMessages(_conversationMessageList.length, messages);
          }
        }, (errorCode) {
          _isLoading = false;
          _noMoreRemoteHistoryMsg = true;
        });
      }
    } else {
      fromIndex = _conversationMessageList.isEmpty ? 0 : _conversationMessageList.last.message.messageId;
      Imclient.getMessages(loadingConv, fromIndex, 20).then((messages) {
        if (loadingConv != _currentConversation) {
          return;
        }
        _insertMessages(_conversationMessageList.length, messages);
        _isLoading = false;
        if (messages.isEmpty) {
          _noMoreLocalHistoryMsg = true;
        }
      });
    }
  }

  void _sendMessage(MessageContent messageContent) {
    if (_currentConversation == null) {
      return;
    }
    Imclient.sendMediaMessage(_currentConversation!, messageContent, successCallback: (int messageUid, int timestamp) {}, errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
      debugPrint("progressCallback:$uploaded,$total");
    }, uploadedCallback: (String remoteUrl) {
      debugPrint("uploadedCallback:$remoteUrl");
    });
  }

  void sendMessage(MessageContent messageContent) {
    if (_currentConversation == null) {
      return;
    }
    Imclient.sendMessage(_currentConversation!, messageContent, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {});
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
