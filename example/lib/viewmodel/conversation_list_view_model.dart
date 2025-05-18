import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:wfc_example/repo/channel_repo.dart';
import 'package:wfc_example/repo/group_repo.dart';

import '../repo/user_repo.dart';
import '../ui_model/ui_conversation_info.dart';

class ConversationListViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ConnectionStatusChangedEvent> _connectionStatusSubscription;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;
  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;
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

  late int _connectionStatus = 0;

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
    Imclient.connectionStatus.then((status) {
      _connectionStatus = status;
      debugPrint('connection status: $status');
    });
    _connectionStatusSubscription = _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _connectionStatus = event.connectionStatus;
      debugPrint('connection status changed: ${event.connectionStatus}');
      if (event.connectionStatus == kConnectionStatusConnected) {
        _loadConversationList();
      }
    });

    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if (!event.hasMore && _connectionStatus == kConnectionStatusConnected) {
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
    _groupInfoUpdatedSubscription = _eventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      _loadConversationList();
    });
    _groupMembersUpdatedSubscription= _eventBus.on<GroupMembersUpdatedEvent>().listen((event) {
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

    _loadConversationList(force: true);
  }

  _preloadConversationTargetAndLastMessageSender(List<ConversationInfo> infos) async {
    Set<String> targetUsers = {};
    List<(String, String)> targetGroupUsers = [];
    Set<String> targetGroups = {};
    Set<String> targetChannels = {};
    for (var info in infos) {
      if (info.conversation.conversationType == ConversationType.Single) {
        targetUsers.add(info.conversation.target);
      } else if (info.conversation.conversationType == ConversationType.Group) {
        targetGroups.add(info.conversation.target);
      } else if (info.conversation.conversationType == ConversationType.Channel) {
        targetChannels.add(info.conversation.target);
      }
      if (info.lastMessage != null) {
        if (info.conversation.conversationType == ConversationType.Group) {
          targetGroupUsers.add((info.conversation.target, info.lastMessage!.fromUser));
        } else {
          targetUsers.add(info.lastMessage!.fromUser);
        }
      }
    }

    UserRepo.getUserInfos(targetUsers.toList());
    for (var rec in targetGroupUsers) {
      UserRepo.getUserInfo(rec.$2, groupId: rec.$1);
    }
    GroupRepo.getGroupInfos(targetGroups.toList());

    for (var channelId in targetChannels) {
      ChannelRepo.getChannelInfo(channelId);
    }
  }

  _loadConversationList({bool force = false}) async {
    if (!force && _connectionStatus != kConnectionStatusConnected) {
      return;
    }
    //var conversationInfos = await Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
    var conversationInfos = await Imclient.getConversationInfos([ConversationType.Single], [0]);
    _conversationList = conversationInfos.map((conv) => UIConversationInfo(conv)).toList();
    if (force) {
      //_preloadConversationTargetAndLastMessageSender(conversationInfos);
    }
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
    _groupInfoUpdatedSubscription.cancel();
    _groupMembersUpdatedSubscription.cancel();
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
