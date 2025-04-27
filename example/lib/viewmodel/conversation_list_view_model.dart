import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';

class ConversationListViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessagesSubscription;
  late StreamSubscription<ConnectionStatusChangedEvent> _connectionStatusSubscription;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<DeleteMessageEvent> _deleteMessageSubscription;
  late StreamSubscription<ClearConversationUnreadEvent> _clearConversationUnreadSubscription;
  late StreamSubscription<ClearConversationsUnreadEvent> _clearConversationsUnreadSubscription;
  late StreamSubscription<SendMessageStartEvent> _sendMessageStartSubscription;
  late StreamSubscription<SendMessageSuccessEvent> _sendMessageSuccessSubscription;
  late StreamSubscription<SendMessageFailureEvent> _sendMessageFailureSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;
  late StreamSubscription<ConversationDraftUpdatedEvent> _draftUpdatedSubscription;
  late StreamSubscription<ConversationSilentUpdatedEvent> _silentUpdatedSubscription;
  late StreamSubscription<ConversationTopUpdatedEvent> _topUpdatedSubscription;

  List<ConversationInfo> _conversationList = [];

  List<ConversationInfo> get conversationList => _conversationList;

  int get unreadMessageCount {
    int count = 0;
    for (ConversationInfo conversation in _conversationList) {
      count += conversation.isSilent ? 0 : conversation.unreadCount.unread;
    }
    return count;
  }

  void setConversationList(List<ConversationInfo> conversationList) {
    _conversationList = conversationList;
    notifyListeners();
  }

  ConversationListViewModel() {
    print("ConversaitonListViewModel construct");
    _connectionStatusSubscription = _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      if (event.connectionStatus == kConnectionStatusConnected) {
        _loadConversationList();
      }
    });

    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if (!event.hasMore) {
        for (Message msg in event.messages) {
          if (msg.messageId > 0) {
            _loadConversationList();
            break;
          }
        }
      }
    });
    _userSettingUpdatedSubscription = _eventBus.on<UserSettingUpdatedEvent>().listen((event) {
      _loadConversationList();
    });
    _recallMessageSubscription = _eventBus.on<RecallMessageEvent>().listen((event) {
      _loadConversationList();
    });
    _deleteMessageSubscription = _eventBus.on<DeleteMessageEvent>().listen((event) {
      _loadConversationList();
    });
    _clearConversationUnreadSubscription = _eventBus.on<ClearConversationUnreadEvent>().listen((event) {
      _loadConversationList();
    });
    _clearConversationsUnreadSubscription = _eventBus.on<ClearConversationsUnreadEvent>().listen((event) {
      _loadConversationList();
    });
    _sendMessageStartSubscription = _eventBus.on<SendMessageStartEvent>().listen((event) {
      _loadConversationList();
    });
    _sendMessageSuccessSubscription = _eventBus.on<SendMessageSuccessEvent>().listen((event) {
      _loadConversationList();
    });
    _sendMessageFailureSubscription = _eventBus.on<SendMessageFailureEvent>().listen((event) {
      _loadConversationList();
    });
    _clearMessagesSubscription = _eventBus.on<ClearMessagesEvent>().listen((event) {
      _loadConversationList();
    });
    _draftUpdatedSubscription = _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      _loadConversationList();
    });
    _silentUpdatedSubscription = _eventBus.on<ConversationSilentUpdatedEvent>().listen((event) {
      _loadConversationList();
    });
    _topUpdatedSubscription = _eventBus.on<ConversationTopUpdatedEvent>().listen((event) {
      _loadConversationList();
    });

    _loadConversationList();
  }

  _loadConversationList() {
    Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]).then((cl) {
      print('ConversaitonListViewModel, load conversation list ${cl.length}');
      _conversationList = cl;
      notifyListeners();
    });
  }

  removeConversation(Conversation conversation, [bool clearMessage = false]) {
    Imclient.removeConversation(conversation, clearMessage);
    for (int i = 0; i < _conversationList.length; i++) {
      if (_conversationList[i].conversation == conversation) {
        _conversationList.removeAt(i);
        notifyListeners();
        break;
      }
    }
  }

  setConversationTop(Conversation conversation, int top) {
    Imclient.setConversationTop(conversation, top, () {
      _loadConversationList();
    },
        (int err) => {
              // do nothing
            });
  }

  clearConversationUnreadStatus(Conversation conversation) {
    Imclient.clearConversationUnreadStatus(conversation).then((onValue) {
      _loadConversationList();
    });
  }

  markConversationAsUnRead(Conversation conversation, [bool unread = true]) {
    Imclient.markAsUnRead(conversation, unread).then((value) {
      _loadConversationList();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _receiveMessagesSubscription.cancel();
    _conversationList.clear();
    _connectionStatusSubscription.cancel();
    _receiveMessageSubscription.cancel();
    _userSettingUpdatedSubscription.cancel();
    _recallMessageSubscription.cancel();
    _deleteMessageSubscription.cancel();
    _clearConversationUnreadSubscription.cancel();
    _clearConversationsUnreadSubscription.cancel();
    _sendMessageStartSubscription.cancel();
    _clearMessagesSubscription.cancel();
    _draftUpdatedSubscription.cancel();
    _silentUpdatedSubscription.cancel();
    _topUpdatedSubscription.cancel();
    _sendMessageSuccessSubscription.cancel();
    _sendMessageFailureSubscription.cancel();
  }
}
