import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart' as mc;
import 'package:imclient/model/conversation.dart';

import '../multi_window/window_event_channel.dart';
import 'call_window_events.dart';
import 'call_window_manager.dart';
import '../multi_window/ipc_codec.dart';
import 'raw_voip_message_content.dart';

/// 主窗口中的音视频通话代理。
///
/// 对应 PC 端 Electron 的 `AvEngineKitProxy`，负责：
/// 1. 监听 IM 消息/会议事件/连接状态变化。
/// 2. 创建/管理 Call 窗口。
/// 3. 把 IM 事件转发到 Call 窗口。
/// 4. 代 Call 窗口执行 IM 操作。
///
/// 注意：主窗口不持有任何 avenginekit 业务逻辑，只通过 [RawVoipMessageContent]
/// 对 VOIP 消息做“原样透传”。
class MainAvEngineKitProxy {
  static const String _tag = 'MainAvEngineKitProxy';
  static final MainAvEngineKitProxy instance = MainAvEngineKitProxy._internal();

  MainAvEngineKitProxy._internal();

  final EventBus _eventBus = Imclient.IMEventBus;
  StreamSubscription? _receiveMessageSubscription;
  StreamSubscription? _conferenceEventSubscription;
  StreamSubscription? _connectionStatusSubscription;

  /// IM 事件串行化链。EventBus 的 listen 回调里启动的异步任务互不等待，
  /// 多条消息/会议事件会在 await 点交错执行——典型场景：两批信令几乎同时
  /// 到达(一通普通来电 + 一个会议邀请)，两个 [_onReceiveMessages] 都看到
  /// `_callWindowId == null`，各自建一个窗口，后建者把前一个还没 ready 的
  /// 窗口关掉(recreate)，前一个窗口积压的信令又被 flush 给后一个窗口，
  /// 两通通话的信令串线。这里把要转发给 Call 窗口的 IM 事件按到达顺序
  /// 串成单链执行，从根上消除交错。
  Future<void> _imEventChain = Future.value();

  void _enqueueImEvent(Future<void> Function() task) {
    _imEventChain = _imEventChain.then((_) async {
      try {
        await task();
      } catch (e, s) {
        print('$_tag IM event task error: $e\n$s');
      }
    });
  }

  /// 当前活跃的 Call 窗口信息。
  int? _callWindowId;
  bool _callWindowReady = false;

  /// 桌面端"是否有通话进行中"的判断依据(主窗口不持有 avenginekit 会话)。
  bool get callActive => _callWindowId != null;

  /// 待转发的事件队列（窗口未 ready 时缓存）。
  final List<_QueuedEvent> _eventQueue = [];

  /// 服务器时间与本机时间的差值(serverTime - localTime)，准静态，缓存一次复用。
  /// 见 [_serverDeltaTime]。
  int? _cachedServerDeltaTime;

  /// 是否已经安装代理。
  bool _installed = false;

  /// 安装代理。
  ///
  /// 应该在主窗口 [Imclient.init] 完成后调用，确保 VOIP 占位类型注册在
  /// IM SDK ready 之后。
  void install() {
    if (_installed) return;
    _installed = true;

    _registerVoipMessageTypes();

    _receiveMessageSubscription =
        _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      _enqueueImEvent(() => _onReceiveMessages(event.messages, event.hasMore));
    });
    _conferenceEventSubscription =
        _eventBus.on<ConferenceEvent>().listen((event) {
      _enqueueImEvent(() async => _onConferenceEvent(event.event));
    });
    _connectionStatusSubscription =
        _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _enqueueImEvent(
          () async => _onConnectionStatusChanged(event.connectionStatus));
    });

    // 监听 Call 窗口发回的事件。
    final channel = WindowEventChannel();
    channel.listen();
    _registerMainWindowHandlers(channel);
  }

  void _registerVoipMessageTypes() {
    for (final entry in _voipTypes) {
      Imclient.registerMessageContent(
        mc.MessageContentMeta(
          entry.type,
          entry.flag,
          () => RawVoipMessageContent(entry.type, entry.flag),
        ),
      );
    }
  }

  void uninstall() {
    _receiveMessageSubscription?.cancel();
    _conferenceEventSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _receiveMessageSubscription = null;
    _conferenceEventSubscription = null;
    _connectionStatusSubscription = null;
    _installed = false;
  }

  /// 主动发起单人/多人通话。
  Future<void> startCall(
    Conversation conversation,
    List<String> participants,
    bool audioOnly, {
    String callExtra = '',
  }) async {
    if (_callWindowId != null) {
      print('$_tag call already in progress');
      return;
    }

    final args = <String, dynamic>{
      'conversation': IpcCodec.encodeConversation(conversation),
      'participants': participants,
      'audioOnly': audioOnly,
      'callExtra': callExtra,
    };

    await _ensureCallWindow(
      conversation: conversation,
      isConference: false,
      initialEvent: CallWindowEvents.startCall,
      initialArgs: args,
    );
  }

  /// 主动创建会议。
  Future<void> startConference({
    required String callId,
    required bool audioOnly,
    String? pin,
    required String host,
    required String title,
    String desc = '',
    bool audience = false,
    bool advance = false,
    bool record = false,
    String extra = '',
    String callExtra = '',
    bool muteAudio = false,
    bool muteVideo = false,
  }) async {
    await _enterConference(CallWindowEvents.startConference, callId, {
      'callId': callId,
      'audioOnly': audioOnly,
      'pin': pin,
      'host': host,
      'title': title,
      'desc': desc,
      'audience': audience,
      'advance': advance,
      'record': record,
      'extra': extra,
      'callExtra': callExtra,
      'muteAudio': muteAudio,
      'muteVideo': muteVideo,
    });
  }

  /// 主动加入会议。
  Future<void> joinConference({
    required String callId,
    required bool audioOnly,
    String? pin,
    required String host,
    required String title,
    String desc = '',
    bool audience = false,
    bool advance = false,
    String extra = '',
    String callExtra = '',
    bool muteAudio = false,
    bool muteVideo = false,
  }) async {
    await _enterConference(CallWindowEvents.joinConference, callId, {
      'callId': callId,
      'audioOnly': audioOnly,
      'pin': pin,
      'host': host,
      'title': title,
      'desc': desc,
      'audience': audience,
      'advance': advance,
      'extra': extra,
      'callExtra': callExtra,
      'muteAudio': muteAudio,
      'muteVideo': muteVideo,
    });
  }

  /// 创建/加入会议的公共路径:先加入会议聊天室(失败也继续,只记日志,
  /// 与既有行为一致),再拉起会议子窗口。
  Future<void> _enterConference(
      String initialEvent, String callId, Map<String, dynamic> args) async {
    if (_callWindowId != null) {
      print('$_tag call already in progress');
      return;
    }

    final completer = Completer<void>();
    Imclient.joinChatroom(
      callId,
      () => completer.complete(),
      (errorCode) {
        print('$_tag joinChatroom $callId failed: $errorCode');
        completer.complete();
      },
    );
    await completer.future;

    await _ensureCallWindow(
      conversation: null,
      isConference: true,
      initialEvent: initialEvent,
      initialArgs: args,
    );
  }

  /// 收到 IM 消息。
  Future<void> _onReceiveMessages(List<Message> messages, bool hasMore) async {
    if (hasMore) return;
    for (final msg in messages) {
      final type = msg.content.meta.type;
      if (!_isVoipMessageType(type)) continue;

      //发送的信令/来电类消息忽略,避免 Call 窗口自己发出的消息回灌;
      //但 ACCEPT/END 例外:多端同步场景(同账号其他端接听/挂断),
      //本端 Call 窗口需要收到它们来结束振铃/通话。
      if (msg.direction == MessageDirection.MessageDirection_Send &&
          type != mc.VOIP_CONTENT_TYPE_ACCEPT &&
          type != mc.VOIP_CONTENT_TYPE_ACCEPT_T &&
          type != mc.VOIP_CONTENT_TYPE_END) {
        print('$_tag drop self-sent voip message type=$type');
        continue;
      }

      // 忽略超过 1 分钟的旧 VOIP 消息，避免离线/历史消息误弹通话窗口。
      // 必须用服务器校准时间比较:serverTime 是服务器时钟,本机时钟与服务器
      // 偏差超过 1 分钟时,不校准就会把实时的来电/信令消息当历史消息全部丢掉
      // (表现为来电不弹窗、去电接不通)。算法与 avenginekit 内部超时判断一致。
      final delta = await _serverDeltaTime();
      final age =
          DateTime.now().millisecondsSinceEpoch + delta - msg.serverTime;
      if (msg.serverTime > 0 && age > 60 * 1000) {
        print(
            '$_tag drop stale voip message type=$type age=${age}ms delta=$delta');
        continue;
      }
      print(
          '$_tag voip message type=$type direction=${msg.direction} age=${age}ms');

      // 来电/邀请类消息需要先创建 Call 窗口。
      var deliveredAsInitialEvent = false;
      if (_callWindowId == null &&
          (type == mc.VOIP_CONTENT_TYPE_START ||
              type == mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT ||
              type == mc.VOIP_CONTENT_CONFERENCE_INVITE)) {
        await _ensureCallWindowFromIncomingMessage(msg);
        // 这条消息已作为新窗口的 initialEvent 投递(窗口 ready 后由
        // _flushEventQueue 补发),这里必须跳过通用投递——否则窗口 ready
        // 后子窗口会再收到一次相同的 START/INVITE,且这次直发落在队列里
        // 已排好的其它信令之后,造成重复振铃/会话状态错乱(有时同步错误)。
        deliveredAsInitialEvent = true;
      }

      if (!deliveredAsInitialEvent) {
        _emitToCallWindow(
            CallWindowEvents.message, IpcCodec.encodeMessage(msg));
      }
    }
  }

  /// 服务器时间与本机时间的差值(serverTime - localTime)。准静态值，缓存一次
  /// 复用，避免每条 VOIP 消息都走一次平台调用。取不到时按 0 处理(退化为
  /// 原来的本机时钟判断)。
  Future<int> _serverDeltaTime() async {
    final cached = _cachedServerDeltaTime;
    if (cached != null) return cached;
    try {
      return _cachedServerDeltaTime = await Imclient.serverDeltaTime;
    } catch (e) {
      print('$_tag get serverDeltaTime failed: $e');
      return 0;
    }
  }

  Future<void> _ensureCallWindowFromIncomingMessage(Message msg) async {
    final int type = msg.content.meta.type;
    final bool isConference = type == mc.VOIP_CONTENT_CONFERENCE_INVITE;
    Conversation? conversation = msg.conversation;
    if (isConference) conversation = null;

    await _ensureCallWindow(
      conversation: conversation,
      isConference: isConference,
      initialEvent: CallWindowEvents.message,
      initialArgs: IpcCodec.encodeMessage(msg),
    );
  }

  /// 收到会议事件。
  void _onConferenceEvent(String event) {
    _emitToCallWindow(CallWindowEvents.conferenceEvent, event);
  }

  /// IM 连接状态变化。
  void _onConnectionStatusChanged(int status) {
    _emitToCallWindow(CallWindowEvents.connectionStatus, status);
  }

  /// 确保 Call 窗口存在并发送初始事件。
  Future<void> _ensureCallWindow({
    Conversation? conversation,
    required bool isConference,
    required String initialEvent,
    required Map<String, dynamic> initialArgs,
  }) async {
    print(
        '$_tag _ensureCallWindow type=${_resolveWindowType(conversation, isConference)}');
    final windowType = _resolveWindowType(conversation, isConference);
    final windowId = await CallWindowManager.instance.createCallWindow(
      type: windowType,
      onReady: () {
        print('$_tag call window ready');
        _callWindowReady = true;
        // 先发初始事件（如 startCall / incoming message），再处理队列里积压的消息，
        // 确保 Call 窗口按正确时序初始化会话状态。
        _emitToCallWindow(initialEvent, initialArgs);
        unawaited(_flushEventQueue());
      },
      onClose: () {
        print('$_tag call window closed');
        _onCallWindowClosed();
      },
    );
    _callWindowId = windowId;
    print('$_tag call window created id=$windowId');
    // Windows 上子窗口初始化可能很快，ready 回调在 createCallWindow 返回前就已
    // 触发；此时 _callWindowId 还未赋值，初始事件会被暂存到队列。这里再刷一次
    // 队列，确保 startCall / 来电消息等能真正发给 Call 窗口。
    unawaited(_flushEventQueue());
  }

  String _resolveWindowType(Conversation? conversation, bool isConference) {
    if (isConference) return 'conference';
    if (conversation?.conversationType == ConversationType.Single)
      return 'single';
    return 'multi';
  }

  /// 转发事件到 Call 窗口，窗口未 ready 时入队。
  void _emitToCallWindow(String event, dynamic args) {
    if (_callWindowReady && _callWindowId != null) {
      _invokeToCallWindow(event, args);
    } else {
      _eventQueue.add(_QueuedEvent(event, args));
    }
  }

  /// 直发事件；目标引擎尚未注册 handler（MissingPlugin）时放回队首，
  /// 等窗口 ready 后的 flush 重投，避免信令静默丢失。
  void _invokeToCallWindow(String event, dynamic args) {
    final id = _callWindowId;
    if (id == null) {
      _eventQueue.insert(0, _QueuedEvent(event, args));
      return;
    }
    unawaited(WindowEventChannel.invokeChecked(id, event, args)
        .then((delivered) {
      if (!delivered && _callWindowId == id) {
        print('$_tag $event 未送达(目标窗口插件未就绪)，放回队首等重投');
        _eventQueue.insert(0, _QueuedEvent(event, args));
      }
    }));
  }

  Future<void> _flushEventQueue() async {
    final id = _callWindowId;
    if (id == null) return;
    while (_eventQueue.isNotEmpty) {
      final item = _eventQueue.removeAt(0);
      final delivered =
          await WindowEventChannel.invokeChecked(id, item.event, item.args);
      if (!delivered && _callWindowId == id) {
        print('$_tag ${item.event} 未送达(目标窗口插件未就绪)，放回队首等下次 flush');
        _eventQueue.insert(0, item);
        return;
      }
    }
  }

  void _onCallWindowClosed() {
    _callWindowId = null;
    _callWindowReady = false;
    _eventQueue.clear();
  }

  /// 注册 Call 窗口会调用的主窗口 IM 代理方法。
  ///
  /// 共用的无副作用读接口(getUserInfo/getUserInfos/getGroupMembers/
  /// currentUserId/clientId/connectionStatus/isLogined/serverDeltaTime)
  /// 已由 MainImclientProxy 在共享域 `im.*` 统一提供,这里只保留通话专有的
  /// 写接口与窗口生命周期事件。
  void _registerMainWindowHandlers(WindowEventChannel channel) {
    channel.register(
        MainWindowEvents.voipStatusChanged, _handleVoipStatusChanged);
    channel.register(MainWindowEvents.windowClosed, _handleWindowClosed);
  }

  Future<dynamic> _handleVoipStatusChanged(dynamic args) async {
    final status = args['status'] as String?;
    final windowId = args['windowId'] as int?;
    print('$_tag voip status changed status=$status windowId=$windowId');
    if (status == 'ready' && windowId != null) {
      await CallWindowManager.instance.onCallWindowReady(windowId);
    }
    return null;
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId != null) {
      await CallWindowManager.instance.onCallWindowClosed(windowId);
    }
    return null;
  }

  bool _isVoipMessageType(int type) {
    return type == mc.VOIP_CONTENT_TYPE_START ||
        type == mc.VOIP_CONTENT_TYPE_END ||
        type == mc.VOIP_CONTENT_TYPE_ACCEPT ||
        type == mc.VOIP_CONTENT_TYPE_ACCEPT_T ||
        type == mc.VOIP_CONTENT_TYPE_SIGNAL ||
        type == mc.VOIP_CONTENT_TYPE_MODIFY ||
        type == mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT ||
        type == mc.VOIP_CONTENT_MUTE_VIDEO ||
        type == mc.VOIP_CONTENT_CONFERENCE_CHANGE_MODE ||
        type == mc.VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER ||
        type == mc.VOIP_CONTENT_CONFERENCE_COMMAND ||
        type == mc.VOIP_CONTENT_MULTI_CALL_ONGOING ||
        type == mc.VOIP_CONTENT_JOIN_CALL_REQUEST;
  }

  /// 所有需要主窗口注册的 VOIP 类型及其对应 flag。
  static final List<_VoipType> _voipTypes = [
    const _VoipType(
        mc.VOIP_CONTENT_TYPE_START, mc.MessageFlag.PERSIST_AND_COUNT),
    const _VoipType(mc.VOIP_CONTENT_TYPE_END, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_ACCEPT, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_ACCEPT_T, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_SIGNAL, mc.MessageFlag.TRANSPARENT),
    const _VoipType(mc.VOIP_CONTENT_TYPE_MODIFY, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT, mc.MessageFlag.PERSIST),
    const _VoipType(mc.VOIP_CONTENT_MUTE_VIDEO, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_CONFERENCE_INVITE, mc.MessageFlag.PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_CONFERENCE_CHANGE_MODE, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_CONFERENCE_COMMAND, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_MULTI_CALL_ONGOING, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(
        mc.VOIP_CONTENT_JOIN_CALL_REQUEST, mc.MessageFlag.NOT_PERSIST),
  ];
}

class _VoipType {
  final int type;
  final mc.MessageFlag flag;
  const _VoipType(this.type, this.flag);
}

class _QueuedEvent {
  final String event;
  final dynamic args;
  _QueuedEvent(this.event, this.args);
}
