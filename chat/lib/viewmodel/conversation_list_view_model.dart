import 'dart:async';
import 'dart:math';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:chat/repo/group_repo.dart';

class ConversationListViewModel extends ChangeNotifier {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ConnectionStatusChangedEvent>
      _connectionStatusSubscription;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<UserSettingUpdatedEvent>
      _userSettingUpdatedSubscription;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<DeleteMessageEvent> _deleteMessageSubscription;
  late StreamSubscription<ClearConversationUnreadEvent>
      _clearConversationUnreadSubscription;
  late StreamSubscription<ClearConversationsUnreadEvent>
      _clearConversationsUnreadSubscription;
  late StreamSubscription<SendMessageStartEvent> _sendMessageStartSubscription;
  late StreamSubscription<SendMessageSuccessEvent>
      _sendMessageSuccessSubscription;
  late StreamSubscription<SendMessageFailureEvent>
      _sendMessageFailureSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;
  late StreamSubscription<ConversationDraftUpdatedEvent>
      _draftUpdatedSubscription;
  late StreamSubscription<ConversationSilentUpdatedEvent>
      _silentUpdatedSubscription;
  late StreamSubscription<ConversationTopUpdatedEvent> _topUpdatedSubscription;

  List<ConversationInfo> _conversationList = [];

  List<ConversationInfo> get conversationList => _conversationList;

  late int _connectionStatus = 0;
  Timer? _debounceTimer;
  bool _loading = false;
  bool _reloadPending = false;
  int? _unreadMessageCount;

  /// 底部 tab 的角标每次 notify 都会读一次。上万会话时不能每次都全量累加。
  int get unreadMessageCount {
    var cached = _unreadMessageCount;
    if (cached != null) return cached;
    int count = 0;
    for (ConversationInfo info in _conversationList) {
      count += info.isSilent ? 0 : info.unreadCount.unread;
    }
    _unreadMessageCount = count;
    return count;
  }

  ConversationListViewModel() {
    debugPrint("ConversationListViewModel construct");
    Imclient.connectionStatus.then((status) {
      _connectionStatus = status;
      debugPrint('connection status: $status');
      if (status == kConnectionStatusConnected) {
        _loadConversationList();
      }
    });
    _connectionStatusSubscription =
        _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _connectionStatus = event.connectionStatus;
      debugPrint('connection status changed: ${event.connectionStatus}');
      if (event.connectionStatus == kConnectionStatusConnected) {
        _loadConversationList();
      }
    });

    _receiveMessageSubscription =
        _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if (!event.hasMore && _connectionStatus == kConnectionStatusConnected) {
        // 只重载收到消息的那几个会话。原先是整批消息触发一次全量
        // getConversationInfos —— 上万会话时每次都是「通道搬运 + 逐条解码
        // lastMessage」的几百毫秒,收消息期间滚动必卡。
        Set<Conversation> touched = {};
        for (Message msg in event.messages) {
          if (msg.messageId > 0) {
            touched.add(msg.conversation);
          }
        }
        if (touched.isNotEmpty) {
          _reloadConversations(touched, insertWhenNotFound: true);
        }
      }
    });

    // 注意:UserInfoUpdatedEvent / GroupInfoUpdatedEvent / GroupMembersUpdatedEvent
    // 曾经也在这里触发全量重载。它们只影响会话行的头像与名称,而这些是
    // UserViewModel / GroupViewModel / ChannelViewModel 通过 Selector 响应式提供的,
    // 会话数据本身(时间、未读、置顶、免打扰、草稿)不受影响,不需要重载。
    // 唯一的例外是通知类消息的摘要要跟着用户名变,由会话 cell 自己订阅这两个事件处理。
    _userSettingUpdatedSubscription =
        _eventBus.on<UserSettingUpdatedEvent>().listen((event) {
      _loadConversationList();
    });
    _recallMessageSubscription =
        _eventBus.on<RecallMessageEvent>().listen((event) {
      _reloadConversation(event.conversation!);
    });
    _deleteMessageSubscription =
        _eventBus.on<DeleteMessageEvent>().listen((event) {
      _reloadConversation(event.conversation!);
    });
    _clearConversationUnreadSubscription =
        _eventBus.on<ClearConversationUnreadEvent>().listen((event) {
      _reloadConversation(event.conversation);
    });
    _clearConversationsUnreadSubscription =
        _eventBus.on<ClearConversationsUnreadEvent>().listen((event) {
      _loadConversationList();
    });
    _sendMessageStartSubscription =
        _eventBus.on<SendMessageStartEvent>().listen((event) {
      if (event.message.messageId != 0) {
        _reloadConversation(event.message.conversation,
            insertWhenNotFound: true);
      }
    });
    _sendMessageSuccessSubscription =
        _eventBus.on<SendMessageSuccessEvent>().listen((event) {
      if (event.message.messageId != 0) {
        _reloadConversation(event.message.conversation,
            insertWhenNotFound: true);
      }
    });
    _sendMessageFailureSubscription =
        _eventBus.on<SendMessageFailureEvent>().listen((event) {
      if (event.message.messageId != 0) {
        _reloadConversation(event.message.conversation,
            insertWhenNotFound: true);
      }
    });
    _clearMessagesSubscription =
        _eventBus.on<ClearMessagesEvent>().listen((event) {
      _reloadConversation(event.conversation);
    });
    _draftUpdatedSubscription =
        _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      _reloadConversation(event.conversation);
    });
    _silentUpdatedSubscription =
        _eventBus.on<ConversationSilentUpdatedEvent>().listen((event) {
      _reloadConversation(event.conversation);
    });
    _topUpdatedSubscription =
        _eventBus.on<ConversationTopUpdatedEvent>().listen((event) {
      _reloadConversation(event.conversation);
    });

    _loadConversationList(force: true);
  }

  _preloadConversationGroupAndChannel(List<ConversationInfo> infos) async {
    Set<String> targetGroups = {};
    Set<String> targetChannels = {};
    // 只预加载最新100 个会话
    infos = infos.sublist(0, min(100, infos.length));
    for (var info in infos) {
      if (info.conversation.conversationType == ConversationType.Single) {
      } else if (info.conversation.conversationType == ConversationType.Group) {
        targetGroups.add(info.conversation.target);
      } else if (info.conversation.conversationType ==
          ConversationType.Channel) {
        targetChannels.add(info.conversation.target);
      }
    }

    GroupRepo.loadConversationGroupInfos(targetGroups.toList());
    //
    // for (var channelId in targetChannels) {
    //   ChannelRepo.getChannelInfo(channelId);
    // }
  }

  _reloadConversation(Conversation conversation,
          {bool insertWhenNotFound = false}) =>
      _reloadConversations([conversation],
          insertWhenNotFound: insertWhenNotFound);

  /// 逐个重载指定会话并按置顶/时间重新排序。相比全量 getConversationInfos,
  /// 通道往返和解码量都只跟受影响会话数相关。
  Future<void> _reloadConversations(Iterable<Conversation> conversations,
      {bool insertWhenNotFound = false}) async {
    bool changed = false;
    for (final conversation in conversations) {
      var info = await Imclient.getConversationInfo(conversation);

      int index = _indexOfConversation(conversation);
      if (index >= 0) {
        if (_sameConversationInfo(_conversationList[index], info)) continue;
        _conversationList[index] = info;
        changed = true;
      } else if (insertWhenNotFound) {
        _conversationList.add(info);
        changed = true;
      }
    }

    if (!changed) return;
    _conversationList.sort((a, b) => a.compareTo(b));
    _unreadMessageCount = null;
    notifyListeners();
  }

  int _indexOfConversation(Conversation conversation) {
    for (int i = 0; i < _conversationList.length; i++) {
      if (_conversationList[i].conversation == conversation) return i;
    }
    return -1;
  }

  /// 两条会话信息在 UI 上是否等价。
  ///
  /// 不用 [ConversationInfo] 自带的 == :它会比较 `lastMessage.content`,
  /// 而多数 [MessageContent] 子类没实现 ==,退化成引用比较后永远不相等。
  /// [Message] 的 == 已覆盖 messageId/messageUid/status/serverTime。
  static bool _sameConversationInfo(ConversationInfo a, ConversationInfo b) =>
      a.timestamp == b.timestamp &&
      a.isTop == b.isTop &&
      a.isSilent == b.isSilent &&
      a.draft == b.draft &&
      a.unreadCount == b.unreadCount &&
      a.lastMessage == b.lastMessage;

  _loadConversationList({bool force = false}) async {
    if (!force && _connectionStatus != kConnectionStatusConnected) {
      return;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _doLoadConversationList(force);
    });
  }

  Future<void> _doLoadConversationList(bool preloadTargets) async {
    // 一次全量加载在上万会话时是几百毫秒的活儿,不能让它们并发堆叠。
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    try {
      var conversationInfos = await Imclient.getConversationInfos([
        ConversationType.Single,
        ConversationType.Group,
        ConversationType.Channel
      ], [
        0
      ]);
      if (preloadTargets) {
        _preloadConversationGroupAndChannel(conversationInfos);
      }

      // 未变的会话沿用旧实例:会话 cell 以 conversationInfo 的引用变化作为
      // 「重新算摘要」的信号,整表换新会让所有可见 cell 白白重算一遍。
      final previous = <Conversation, ConversationInfo>{
        for (final info in _conversationList) info.conversation: info
      };
      for (int i = 0; i < conversationInfos.length; i++) {
        final old = previous[conversationInfos[i].conversation];
        if (old != null && _sameConversationInfo(old, conversationInfos[i])) {
          conversationInfos[i] = old;
        }
      }

      _conversationList = conversationInfos;
      _unreadMessageCount = null;
      notifyListeners();
    } finally {
      _loading = false;
      if (_reloadPending) {
        _reloadPending = false;
        _loadConversationList();
      }
    }
  }

  removeConversation(Conversation conversation, [bool clearMessage = false]) {
    Imclient.removeConversation(conversation, clearMessage);
    for (int i = 0; i < _conversationList.length; i++) {
      if (_conversationList[i].conversation == conversation) {
        _conversationList.removeAt(i);
        _unreadMessageCount = null;
        notifyListeners();
        break;
      }
    }
  }

  setConversationTop(Conversation conversation, int top) {
    Imclient.setConversationTop(conversation, top, () {
      _reloadConversation(conversation);
    },
        (int err) => {
              // do nothing
            });
  }

  clearConversationUnreadStatus(Conversation conversation) {
    Imclient.clearConversationUnreadStatus(conversation).then((onValue) {
      _reloadConversation(conversation);
    });
  }

  markConversationAsUnRead(Conversation conversation, [bool unread = true]) {
    Imclient.markAsUnRead(conversation, unread).then((value) {
      _reloadConversation(conversation);
    });
  }

  void reset() {
    _conversationList = [];
    _unreadMessageCount = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    super.dispose();
  }
}
