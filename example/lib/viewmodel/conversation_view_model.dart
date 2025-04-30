import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:wfc_example/ui_model/ui_message.dart';

class ConversationViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<DeleteMessageEvent> _deleteMessageSubscription;
  late StreamSubscription<SendMessageStartEvent> _sendMessageStartSubscription;
  late StreamSubscription<SendMessageSuccessEvent> _sendMessageSuccessSubscription;
  late StreamSubscription<SendMessageFailureEvent> _sendMessageFailureSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;
  late StreamSubscription<ConversationDraftUpdatedEvent> _draftUpdatedSubscription;

  //  消息倒序，第 0 条是最新消息，但UI 层list 进行了 reverse
  List<UIMessage> _conversationMessageList = [];
  late Conversation _currentConversation;
  late String _draft;
  late bool _isLoading = false;
  late bool _noMoreLocalHistoryMsg = false;
  late bool _noMoreRemoteHistoryMsg = false;

  List<UIMessage> get conversationMessageList => _conversationMessageList;

  String get draft => _draft;

  int get unreadMessageCount {
    return 0;
  }

  void setConversation(Conversation conversation) {
    _noMoreLocalHistoryMsg = false;
    _noMoreRemoteHistoryMsg = false;
    _conversationMessageList = [];
    _currentConversation = conversation;
    Imclient.getMessages(conversation, 0, 20).then((messages) {
      _conversationMessageList = messages.map((message) => UIMessage(message)).toList();
      notifyListeners();
    });
  }

  ConversationViewModel() {
    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      var newMsg = false;
      for (Message msg in event.messages) {
        if (msg.conversation == _currentConversation) {
          if (msg.messageId == 0) {
            // TODO
            // typing
            continue;
          }
          _conversationMessageList.insert(0, UIMessage(msg));
          newMsg = true;
        }
      }
      // newMsg ? notifyListeners() : null;
      if (newMsg) {
        notifyListeners();
      }
    });
    _recallMessageSubscription = _eventBus.on<RecallMessageEvent>().listen((event) {
      var msgUid = event.messageUid;
      for (UIMessage msg in _conversationMessageList) {
        if (msg.message.messageUid == msgUid) {
          _conversationMessageList.remove(msg);
          notifyListeners();
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
      if (_currentConversation == msg.conversation) {
        _conversationMessageList.add(UIMessage(msg));
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
    if (_conversationMessageList.isNotEmpty) {
      fromIndex = _conversationMessageList.last.message.messageId;
    } else {
      _isLoading = false;
      return;
    }

    var loadingConv = _currentConversation;
    if (_noMoreLocalHistoryMsg) {
      if (_noMoreRemoteHistoryMsg) {
        _isLoading = false;
        return;
      } else {
        fromIndex = _conversationMessageList.last.message.messageUid;
        Imclient.getRemoteMessages(loadingConv, fromIndex!, 20, (messages) {
          if (loadingConv != _currentConversation) {
            return;
          }
          if (messages.isEmpty) {
            _noMoreLocalHistoryMsg = true;
          }
          _isLoading = false;
          _insertMessages(_conversationMessageList.length, messages);
        }, (errorCode) {
          _isLoading = false;
          _noMoreRemoteHistoryMsg = true;
        });
      }
    } else {
      Imclient.getMessages(loadingConv, fromIndex, 20).then((value) {
        if (loadingConv != _currentConversation) {
          return;
        }
        _insertMessages(_conversationMessageList.length, value);
        _isLoading = false;
        if (value.isEmpty) {
          _noMoreLocalHistoryMsg = true;
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _conversationMessageList.clear();
    _receiveMessageSubscription.cancel();
    _recallMessageSubscription.cancel();
    _deleteMessageSubscription.cancel();
    _sendMessageStartSubscription.cancel();
    _clearMessagesSubscription.cancel();
    _draftUpdatedSubscription.cancel();
    _sendMessageSuccessSubscription.cancel();
    _sendMessageFailureSubscription.cancel();
  }
}
