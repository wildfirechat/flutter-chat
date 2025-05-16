import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';

import '../repo/user_repo.dart';
import '../ui_model/ui_conversation_info.dart';

class ConversationListViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ConnectionStatusChangedEvent> _connectionStatusSubscription;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
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

  List<UIConversationInfo> _conversationList = [];

  List<UIConversationInfo> get conversationList => _conversationList;

  int get unreadMessageCount {
    int count = 0;
    for (UIConversationInfo info in _conversationList) {
      var convInfo = info.conversationInfo;
      count += convInfo.isSilent ? 0 : convInfo.unreadCount.unread;
    }
    return count;
  }

  ConversationListViewModel() {
    debugPrint("ConversationListViewModel construct");
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
    _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
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

    _preloadFriendUserInfos().then((_) {
      _loadConversationList();
    });
  }

  _preloadFriendUserInfos() async {
    var friendList = await Imclient.getMyFriendList(refresh: false);
    await UserRepo.getUserInfos(friendList);
  }

  _loadConversationList() async {
    //var conversationInfos = await Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
    var conversationInfos = await Imclient.getConversationInfos([ConversationType.Single], [0]);
    _conversationList = conversationInfos.map((conv) => UIConversationInfo(conv)).toList();
    notifyListeners();
  }

  removeConversation(Conversation conversation, [bool clearMessage = false]) {
    Imclient.removeConversation(conversation, clearMessage);
    for (int i = 0; i < _conversationList.length; i++) {
      if (_conversationList[i].conversationInfo.conversation == conversation) {
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
    _conversationList.clear();
    _connectionStatusSubscription.cancel();
    _receiveMessageSubscription.cancel();
    _userSettingUpdatedSubscription.cancel();
    _userInfoUpdatedSubscription.cancel();
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
