import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall, MissingPluginException;
import 'package:path/path.dart' as path;

import '../imclient_channel.dart';
import '../../model/im_constant.dart';
import 'wfclient_bindings.dart';

/// 桌面端（macOS/Windows/Linux）imclient 通道的唯一实现。
///
/// 通过 dart:ffi 直接驱动 libMarsWrapper（WFClient C API），取代原先
/// macOS(ObjC++)/Windows(C++)/Linux(C++) 三份各 ~3200 行的原生插件。
/// 对上层保持与移动端 MethodChannel 完全一致的方法名/参数/回调契约
/// （契约以 imclient_method_channel.dart 的 setMethodCallHandler 分支和
/// Android 实现为准）。
///
/// 线程模型：SDK 回调由共享 C 垫片 wfc_dart_bridge.c 在回调线程上同步拷贝
/// 载荷后经 Dart_PostCObject 投递到本 isolate 的 ReceivePort（SDK 回调的
/// 字符串指针指向栈上临时对象，回调返回即失效，必须同步拷贝）。
class ImclientFfiChannel implements ImclientChannel {
  ImclientFfiChannel()
      : _wf = WFClientBindings(_openLibrary(_wfclientCandidates())),
        _bridge = _BridgeBindings(_openBridge());

  final WFClientBindings _wf;
  final _BridgeBindings _bridge;

  Future<dynamic> Function(MethodCall call)? _handler;

  /// 垫片消息接收端口；非 null 即表示 initProto 已完成。
  ReceivePort? _receivePort;

  /// getMessages 系列内部等待（区别于 Dart 层显式传入的正数 requestId，
  /// 内部请求使用负数 id，经 p_obj 往返）。
  int _nextInternalId = -1;
  final Map<int, Completer<String>> _internalString = {};

  /// Dart 层 requestId → general_string 成功回调的载荷转换器。
  final Map<int, void Function(String json)> _pendingString = {};

  // ---------------------------------------------------------------------
  // ImclientChannel
  // ---------------------------------------------------------------------

  @override
  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler) {
    _handler = handler;
  }

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    final args = (arguments is Map) ? arguments : const <String, dynamic>{};
    final result = await _dispatch(method, args);
    return result as T?;
  }

  /// 把事件按 MethodChannel 的形态回放给上层 handler。
  void _emit(String method, dynamic arguments) {
    final handler = _handler;
    if (handler == null) return;
    Future(() => handler(MethodCall(method, arguments))).catchError((e, s) {
      debugPrint('[imclient][ffi] handler error on $method: $e\n$s');
    });
  }

  // ---------------------------------------------------------------------
  // 动态库加载
  // ---------------------------------------------------------------------

  static List<String> _wfclientCandidates() {
    final env = Platform.environment['WFC_MARSLIB_PATH'];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      return [
        if (env != null) env,
        'libMarsWrapper.dylib',
        '@rpath/libMarsWrapper.dylib',
        '$exeDir/../Frameworks/libMarsWrapper.dylib',
      ];
    }
    if (Platform.isWindows) {
      return [if (env != null) env, 'MarsWrapper.dll', '$exeDir\\MarsWrapper.dll'];
    }
    return [
      if (env != null) env,
      'libMarsWrapper.so',
      '$exeDir/lib/libMarsWrapper.so',
    ];
  }

  static DynamicLibrary _openLibrary(List<String> candidates) {
    Object? lastError;
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('无法加载 WFClient 动态库，尝试路径: $candidates，'
        '最后错误: $lastError');
  }

  static DynamicLibrary _openBridge() {
    if (Platform.isMacOS) {
      // 垫片由 CocoaPods 编译进 imclient framework，随应用一起加载。
      return DynamicLibrary.process();
    }
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) {
      return _openLibrary(
          ['wfc_dart_bridge.dll', '$exeDir\\wfc_dart_bridge.dll']);
    }
    return _openLibrary(
        ['libwfc_dart_bridge.so', '$exeDir/lib/libwfc_dart_bridge.so']);
  }

  // ---------------------------------------------------------------------
  // 垫片消息路由（tag 常量与 wfc_dart_bridge.c 保持一致）
  // ---------------------------------------------------------------------

  void _onBridgeMessage(dynamic message) {
    if (message is! List || message.isEmpty) return;
    final tag = message[0] as int;
    String str(int i) =>
        utf8.decode(message[i] as Uint8List, allowMalformed: true);
    switch (tag) {
      case _BridgeTag.connectionStatus:
        _emit('onConnectionStatusChanged', message[1] as int);
        break;
      case _BridgeTag.connectedToServer:
        _emit('onConnected', {
          'host': str(1),
          'ip': str(2),
          'port': message[3] as int,
          'mainNetwork': message[4] as bool,
        });
        break;
      case _BridgeTag.receiveMessage:
        _emit('onReceiveMessage', {
          'messages': _jsonList(str(1)),
          'hasMore': message[2] as bool,
        });
        break;
      case _BridgeTag.recallMessage:
        _emit('onRecallMessage',
            {'operator': str(1), 'messageUid': message[2] as int});
        break;
      case _BridgeTag.deleteMessage:
        _emit('onDeleteMessage', {'messageUid': message[1] as int});
        break;
      case _BridgeTag.userInfoUpdated:
        _emit('onUserInfoUpdated', {'users': _jsonList(str(1))});
        break;
      case _BridgeTag.groupInfoUpdated:
        _emit('onGroupInfoUpdated', {'groups': _jsonList(str(1))});
        break;
      case _BridgeTag.groupMemberUpdated:
        // PC SDK 仅回传 groupId，成员列表由上层自行拉取。
        _emit('onGroupMemberUpdated', {'groupId': str(1), 'members': []});
        break;
      case _BridgeTag.friendListUpdated:
        _emit('onFriendListUpdated', {'friends': _jsonList(str(1))});
        break;
      case _BridgeTag.friendRequestUpdated:
        _emit('onFriendRequestUpdated', {'requests': _jsonList(str(1))});
        break;
      case _BridgeTag.settingUpdated:
        _emit('onSettingUpdated', null);
        break;
      case _BridgeTag.channelInfoUpdated:
        _emit('onChannelInfoUpdated', {'channels': _jsonList(str(1))});
        break;
      case _BridgeTag.joinGroupRequestUpdated:
        _emit('onJoinGroupRequestUpdated', null);
        break;
      case _BridgeTag.domainInfoUpdated:
        _emit('onDomainInfoUpdate', {'domainInfo': _json(str(1))});
        break;
      case _BridgeTag.onlineEventUpdated:
        _emit('onUserOnlineEvent', {'states': _jsonList(str(1))});
        break;
      case _BridgeTag.messageDelivered:
        final delivered = _json(str(1));
        if (delivered is Map) {
          _emit('onMessageDelivered', delivered);
        }
        break;
      case _BridgeTag.messageReaded:
        _emit('onMessageReaded', {'readeds': _jsonList(str(1))});
        break;
      case _BridgeTag.generalVoidSuccess:
        _emit('onOperationVoidSuccess', {'requestId': message[1] as int});
        break;
      case _BridgeTag.generalStringSuccess:
        _onGeneralStringSuccess(message[1] as int, str(2));
        break;
      case _BridgeTag.generalError:
        _onGeneralError(message[1] as int, message[2] as int);
        break;
      case _BridgeTag.sendMessageSuccess:
        _emit('onSendMessageSuccess', {
          'requestId': message[1] as int,
          'messageId': message[2] as int,
          'messageUid': message[3] as int,
          'timestamp': message[4] as int,
        });
        break;
      case _BridgeTag.sendMessagePrepared:
        // 与原生实现保持一致：桌面端不分发 prepared 事件。
        break;
      case _BridgeTag.sendMessageProgress:
        _emit('onSendMediaMessageProgress', {
          'requestId': message[1] as int,
          'messageId': message[2] as int,
          'uploaded': message[3] as int,
          'total': message[4] as int,
        });
        break;
      case _BridgeTag.sendMessageUploaded:
        _emit('onSendMediaMessageUploaded', {
          'requestId': message[1] as int,
          'messageId': message[2] as int,
          'remoteUrl': str(3),
        });
        break;
      case _BridgeTag.sendMessageError:
        _emit('onSendMessageFailure', {
          'requestId': message[1] as int,
          'messageId': message[2] as int,
          'errorCode': message[3] as int,
        });
        break;
      case _BridgeTag.uploadMediaProgress:
        _emit('onUploadMediaProgress', {
          'requestId': message[1] as int,
          'uploaded': message[2] as int,
          'total': message[3] as int,
        });
        break;
      default:
        debugPrint('[imclient][ffi] unknown bridge tag: $tag');
    }
  }

  void _onGeneralStringSuccess(int requestId, String json) {
    if (requestId < 0) {
      _internalString.remove(requestId)?.complete(json);
      return;
    }
    final transform = _pendingString.remove(requestId);
    if (transform != null) {
      transform(json);
      return;
    }
    // 默认契约（Android 参考实现）：onOperationStringSuccess 携带原始字符串。
    _emit('onOperationStringSuccess', {'requestId': requestId, 'string': json});
  }

  void _onGeneralError(int requestId, int errorCode) {
    if (requestId < 0) {
      _internalString.remove(requestId)?.complete('');
      return;
    }
    _pendingString.remove(requestId);
    _emit('onOperationFailure', {'requestId': requestId, 'errorCode': errorCode});
  }

  // ---------------------------------------------------------------------
  // 序列化/反序列化辅助
  // ---------------------------------------------------------------------

  static dynamic _json(String s) {
    if (s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _jsonList(String s) {
    final v = _json(s);
    return v is List ? v : <dynamic>[];
  }

  /// 消息数组：与原生实现的 ReversedJsonArrayToEncodable 保持一致（倒序）。
  static List<dynamic> _reversedJsonList(String s) =>
      _jsonList(s).reversed.toList();

  static Map<dynamic, dynamic> _jsonMap(String s) {
    final v = _json(s);
    return v is Map ? v : <dynamic, dynamic>{};
  }

  /// PC SDK 的 {key,value} 数组转 Map，与移动端原生 SDK 返回的 Map 格式保持一致。
  static Map<dynamic, dynamic> _strLongMapFromList(String s) {
    final v = _json(s);
    final map = <dynamic, dynamic>{};
    if (v is List) {
      for (final item in v) {
        if (item is Map && item['key'] != null) {
          map[item['key']] = item['value'];
        }
      }
    } else if (v is Map) {
      v.forEach((key, value) {
        map[key] = value;
      });
    }
    return map;
  }

  /// 读取 SDK 返回的字符串并按约定 releaseDllString 释放。
  String _takeDllString(Pointer<Char> p, int len) {
    if (p == nullptr) return '';
    final s = len == 0
        ? ''
        : utf8.decode(p.cast<Uint8>().asTypedList(len), allowMalformed: true);
    _wf.releaseDllString(p);
    return s;
  }

  /// 同步的 out-string 调用模式：const char* fn(..., size_t *retlen)。
  String _outString(Pointer<Char> Function(Pointer<Size> retlen) call) {
    return using((arena) {
      final lenPtr = arena<Size>();
      final p = call(lenPtr);
      return _takeDllString(p, lenPtr.value);
    });
  }

  // ---- 入参 ----

  static String _str(Map args, String key, [String def = '']) {
    final v = args[key];
    return v is String ? v : def;
  }

  static int _int(Map args, String key, [int def = 0]) {
    final v = args[key];
    return v is num ? v.toInt() : def;
  }

  static bool _bool(Map args, String key, [bool def = false]) {
    final v = args[key];
    return v is bool ? v : def;
  }

  static List<int> _intList(Map args, String key) {
    final v = args[key];
    if (v is! List) return const [];
    return v.map((e) => (e as num).toInt()).toList();
  }

  static List<String> _strList(Map args, String key) {
    final v = args[key];
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  // ---- 出参（native） ----

  static _NS _ns(Arena arena, String s) {
    final units = utf8.encode(s);
    final ptr = arena<Uint8>(units.length + 1);
    ptr.asTypedList(units.length + 1)
      ..setAll(0, units)
      ..[units.length] = 0;
    return _NS(ptr.cast<Char>(), units.length);
  }

  static _NSArray _nsArray(Arena arena, List<String> list) {
    if (list.isEmpty) return _NSArray(nullptr, nullptr, 0);
    final ptrs = arena<Pointer<Char>>(list.length);
    final lens = arena<Size>(list.length);
    for (var i = 0; i < list.length; i++) {
      final ns = _ns(arena, list[i]);
      ptrs[i] = ns.ptr;
      lens[i] = ns.len;
    }
    return _NSArray(ptrs, lens, list.length);
  }

  static Pointer<Int32> _i32Array(Arena arena, List<int> list) {
    if (list.isEmpty) return nullptr;
    final p = arena<Int32>(list.length);
    for (var i = 0; i < list.length; i++) {
      p[i] = list[i];
    }
    return p;
  }

  static Pointer<Int64> _i64Array(Arena arena, List<int> list) {
    if (list.isEmpty) return nullptr;
    final p = arena<Int64>(list.length);
    for (var i = 0; i < list.length; i++) {
      p[i] = list[i];
    }
    return p;
  }

  /// 会话参数：Dart 层以嵌套 conversation 传递，兼容顶层平铺（与原生
  /// Conversation(map) 构造保持一致）。
  static _Conv _conv(Map args) {
    Map source = args;
    final nested = args['conversation'];
    if (nested is Map) source = nested;
    return _Conv(_int(source, 'type'), _str(source, 'target'),
        _int(source, 'line'));
  }

  /// 消息内容 payload → SDK JSON（与原生 MessagePayload::ToEncodable 一致，
  /// binaryContent 使用 base64 编码）。
  static String _payloadJson(Map? content) {
    final c = content ?? const {};
    final binary = c['binaryContent'];
    return jsonEncode({
      'type': _int(c, 'type'),
      'searchableContent': _str(c, 'searchableContent'),
      'pushContent': _str(c, 'pushContent'),
      'pushData': _str(c, 'pushData'),
      'content': _str(c, 'content'),
      'binaryContent': binary is Uint8List ? base64Encode(binary) : '',
      'localContent': _str(c, 'localContent'),
      'remoteMediaUrl': _str(c, 'remoteMediaUrl'),
      'localMediaPath': _str(c, 'localMediaPath'),
      'mediaType': _int(c, 'mediaType'),
      'mentionedType': _int(c, 'mentionedType'),
      'mentionedTargets': _strList(c, 'mentionedTargets'),
      'extra': _str(c, 'extra'),
    });
  }

  /// 群操作的通知消息内容（可选）。
  static String _notifyContentJson(Map args) {
    final notify = args['notifyContent'];
    if (notify is! Map) return '';
    return _payloadJson(notify);
  }

  void _logStub(String method, String fallback) {
    debugPrint('[imclient][stub] $method 在桌面端未实现，返回兜底值: $fallback');
  }

  // ---------------------------------------------------------------------
  // 初始化
  // ---------------------------------------------------------------------

  void _initProto(Map args) {
    if (_receivePort != null) return;

    final initResult = _bridge.init(NativeApi.initializeApiDLData);
    if (initResult != 0) {
      throw StateError('wfc_dart_bridge_init failed: $initResult');
    }
    final port = ReceivePort()..listen(_onBridgeMessage);
    _receivePort = port;
    _bridge.setPort(port.sendPort.nativePort);

    using((arena) {
      final appName = _ns(arena, _str(args, 'appName', 'wfc_pc'));
      _wf.setAppName(appName.ptr, appName.len);
      final appDataPath = _str(args, 'appDataPath');
      if (appDataPath.isNotEmpty) {
        final p = _ns(arena, appDataPath);
        _wf.setAppDataPath(p.ptr, p.len);
      }
      final packageName =
          _ns(arena, _str(args, 'packageName', _str(args, 'appName', 'wfc_pc')));
      _wf.setPackageName(packageName.ptr, packageName.len);
      final dbPath = _str(args, 'dbPath');
      if (dbPath.isNotEmpty) {
        final p = _ns(arena, dbPath);
        _wf.setDBPath(p.ptr, p.len);
      }
    });

    _wf.setConnectionStatusListener(_bridge.fn('wfc_on_connection_status'));
    _wf.setConnectToServerListener(
      _bridge.fn('wfc_on_connecting'),
      _bridge.fn('wfc_on_connected'),
    );
    _wf.setReceiveMessageListener(
      _bridge.fn('wfc_on_receive_message'),
      _bridge.fn('wfc_on_recall_message'),
      _bridge.fn('wfc_on_delete_message'),
      _bridge.fn('wfc_on_message_delivered'),
      _bridge.fn('wfc_on_message_readed'),
    );
    _wf.setUserInfoUpdateListener(_bridge.fn('wfc_on_userinfo_updated'));
    _wf.setGroupInfoUpdateListener(_bridge.fn('wfc_on_groupinfo_updated'));
    _wf.setGroupMemberUpdateListener(_bridge.fn('wfc_on_groupmember_updated'));
    _wf.setFriendUpdateListener(_bridge.fn('wfc_on_friendlist_updated'));
    _wf.setFriendRequestListener(_bridge.fn('wfc_on_friendrequest_updated'));
    _wf.setSettingUpdateListener(_bridge.fn('wfc_on_setting_updated'));
    _wf.setJoinGroupRequestUpdateListener(_bridge.fn('wfc_on_join_group_request_updated'));
    _wf.setChannelInfoUpdateListener(_bridge.fn('wfc_on_channelinfo_updated'));
    _wf.setDomainInfoUpdateListener(_bridge.fn('wfc_on_domain_info_updated'));
    _wf.setOnlineEventListener(_bridge.fn('wfc_on_online_event_updated'));
  }

  // ---- 请求级回调指针 ----

  Pointer<NativeFunction<Native_fun_general_void_success_callback>>
      get _cbVoid => _bridge.fn('wfc_on_general_void_success');
  Pointer<NativeFunction<Native_fun_general_string_success_callback>>
      get _cbString => _bridge.fn('wfc_on_general_string_success');
  Pointer<NativeFunction<Native_fun_general_error_callback>> get _cbError =>
      _bridge.fn('wfc_on_general_error');

  static Pointer<Void> _reqPtr(int requestId) =>
      Pointer<Void>.fromAddress(requestId);

  /// getMessages 系列的内部等待：返回倒序消息列表。
  Future<List<dynamic>> _awaitMessages(
      void Function(Pointer<Void> pObj) invoke) {
    final id = _nextInternalId--;
    final completer = Completer<String>();
    _internalString[id] = completer;
    invoke(_reqPtr(id));
    return completer.future.then(_reversedJsonList);
  }

  /// 通用字符串回调的内部等待。
  Future<String> _awaitString(
      void Function(Pointer<Void> pObj) invoke) {
    final id = _nextInternalId--;
    final completer = Completer<String>();
    _internalString[id] = completer;
    invoke(_reqPtr(id));
    return completer.future;
  }

  // ---------------------------------------------------------------------
  // 分发（方法名与移动端 MethodChannel 完全一致）
  // ---------------------------------------------------------------------

  Future<Object?> _dispatch(String method, Map args) async {
    switch (method) {
      // ---- 生命周期/环境 ----
      case 'initProto':
        _initProto(args);
        return null;
      case 'getClientId':
        return _outString((lp) => _wf.getClientId(lp));
      case 'currentUserId':
        return _outString((lp) => _wf.getCurrentUserId(lp));
      case 'getProtoRevision':
        return _outString((lp) => _wf.getProtoRevision(lp));
      case 'connect':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          final token = _ns(a, _str(args, 'token'));
          return _wf.connect2Server(
              userId.ptr, userId.len, token.ptr, token.len);
        });
      case 'disconnect':
        _wf.disconnect(_bool(args, 'clearSession') ? 1 : 0);
        return null;
      case 'connectionStatus':
        return _wf.getConnectionStatus();
      case 'isLogined':
        return _wf.isLogin();
      case 'serverDeltaTime':
        return _wf.getServerDeltaTime();
      case 'isMeshEnabled':
        return _wf.isMeshEnabled();
      case 'getDomainInfo':
        return using((a) {
          final domainId = _ns(a, _str(args, 'domainId'));
          return _json(_outString((lp) => _wf.getDomainInfo(domainId.ptr, domainId.len, _bool(args, 'refresh'), lp)));
        });
      case 'getRemoteDomains':
        return _jsonList(
            await _awaitString((pObj) => _wf.getRemoteDomains(_cbString, _cbError, pObj, 0)));
      case 'setBackupAddress':
        return using((a) {
          final host = _ns(a, _str(args, 'host'));
          _wf.setBackupAddress(host.ptr, host.len, _int(args, 'port'));
          return null;
        });
      case 'useSM4':
        _wf.useSM4();
        return null;
      case 'setLiteMode':
        _wf.setLiteMode(_bool(args, 'liteMode'));
        return null;
      case 'setBackupAddressStrategy':
        _wf.setBackupAddressStrategy(_int(args, 'strategy'));
        return null;
      case 'setProtoUserAgent':
        return using((a) {
          final agent = _ns(a, _str(args, 'agent'));
          _wf.setUserAgent(agent.ptr, agent.len);
          return null;
        });
      case 'addHttpHeader':
        return using((a) {
          final header = _ns(a, _str(args, 'header'));
          final value = _ns(a, _str(args, 'value'));
          _wf.addHttpHeader(header.ptr, header.len, value.ptr, value.len);
          return null;
        });
      case 'setProxyInfo':
        return using((a) {
          final host = _ns(a, _str(args, 'host'));
          final ip = _ns(a, _str(args, 'ip'));
          final name = _ns(a, _str(args, 'userName'));
          final password = _ns(a, _str(args, 'password'));
          _wf.setProxyInfo(host.ptr, host.len, ip.ptr, ip.len,
              _int(args, 'port'), name.ptr, name.len, password.ptr,
              password.len);
          return null;
        });
      case 'registerMessage':
        _wf.registerMessageFlag(_int(args, 'type'), _int(args, 'flag'));
        return null;
      case 'startLog':
      case 'stopLog':
      case 'setSendLogCommand':
      case 'setDeviceToken':
      case 'setVoipDeviceToken':
        return null; // 桌面端无对应实现（与原生插件行为一致）。
      case 'getLogFilesPath':
        return _outString((lp) => _wf.getLogFilesPath(lp));

      // ---- 会话 ----
      case 'getConversationInfos':
        return using((a) {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          return _json(_outString((lp) => _wf.getConversationInfos(
              _i32Array(a, types),
              types.length,
              _i32Array(a, lines),
              lines.length,
              lp)));
        });
      case 'getConversationInfo':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _json(_outString((lp) => _wf.getConversationInfo(
              c.type, target.ptr, target.len, c.line, lp)));
        });
      case 'searchConversation':
        return using((a) {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          final keyword = _ns(a, _str(args, 'keyword'));
          return _json(_outString((lp) => _wf.searchConversation(
              _i32Array(a, types),
              types.length,
              _i32Array(a, lines),
              lines.length,
              keyword.ptr,
              keyword.len,
              lp)));
        });
      case 'removeConversation':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.removeConversation(c.type, target.ptr, target.len, c.line,
              _bool(args, 'clearMessage'));
          return null;
        });
      case 'setConversationTop':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.setConversationTop(c.type, target.ptr, target.len, c.line,
              _int(args, 'isTop'), _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'setConversationSilent':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.setConversationSlient(c.type, target.ptr, target.len, c.line,
              _bool(args, 'isSilent'), _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'setConversationDraft':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final draft = _ns(a, _str(args, 'draft'));
          _wf.setConversationDraft(
              c.type, target.ptr, target.len, c.line, draft.ptr, draft.len);
          return null;
        });
      case 'setConversationTimestamp':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.setConversationTimestamp(c.type, target.ptr, target.len, c.line,
              _int(args, 'timestamp'));
          return null;
        });
      case 'getFirstUnreadMessageId':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _wf.getConversationFirstUnreadMessageId(
              c.type, target.ptr, target.len, c.line);
        });
      case 'getConversationUnreadCount':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _json(_outString((lp) => _wf.getConversationUnreadCount(
              c.type, target.ptr, target.len, c.line, lp)));
        });
      case 'getConversationsUnreadCount':
        return using((a) {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          return _json(_outString((lp) => _wf.getUnreadCount(
              _i32Array(a, types),
              types.length,
              _i32Array(a, lines),
              lines.length,
              lp)));
        });
      case 'clearConversationUnreadStatus':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _wf.clearUnreadStatus(c.type, target.ptr, target.len, c.line);
        });
      case 'clearConversationsUnreadStatus':
        return using((a) {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          return _wf.clearUnreadStatusEx(_i32Array(a, types), types.length,
              _i32Array(a, lines), lines.length);
        });
      case 'clearAllUnreadStatus':
        return _wf.clearAllUnreadStatus();
      case 'clearMessageUnreadStatus':
        return _wf.clearMessageUnreadStatus(_int(args, 'messageId'));
      case 'clearMessageUnreadStatusBefore':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _wf.clearMessageUnreadStatusBefore(
              c.type, target.ptr, target.len, c.line, _int(args, 'messageId'));
        });
      case 'markAsUnRead':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final uid = _wf.setLastReceivedMessageUnRead(
              c.type, target.ptr, target.len, c.line, 0, 0);
          return uid > 0;
        });
      case 'getConversationRead':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _strLongMapFromList(_outString((lp) => _wf.getConversationRead(
              c.type, target.ptr, target.len, c.line, lp)));
        });
      case 'getMessageDelivery':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _strLongMapFromList(_outString((lp) =>
              _wf.getMessageDelivery(c.type, target.ptr, target.len, lp)));
        });

      // ---- 消息查询 ----
      case 'getMessages':
        {
          final c = _conv(args);
          final contentTypes = _intList(args, 'contentTypes');
          final fromIndex = _int(args, 'fromIndex');
          final count = _int(args, 'count');
          final withUser = _str(args, 'withUser');
          // 参考 iOS：count > 0 表示向前（旧消息）。
          final direction = count > 0;
          return _awaitMessages((pObj) => using((a) {
                final target = _ns(a, c.target);
                final wu = _ns(a, withUser);
                _wf.getMessagesV2(
                    c.type,
                    target.ptr,
                    target.len,
                    c.line,
                    _i32Array(a, contentTypes),
                    contentTypes.length,
                    fromIndex,
                    direction,
                    count.abs(),
                    wu.ptr,
                    wu.len,
                    _cbString,
                    _cbError,
                    pObj,
                    0);
              }));
        }
      case 'getMessagesByStatus':
        {
          final c = _conv(args);
          final statuses = _intList(args, 'messageStatus');
          final fromIndex = _int(args, 'fromIndex');
          final count = _int(args, 'count');
          final withUser = _str(args, 'withUser');
          final direction = count > 0;
          return _awaitMessages((pObj) => using((a) {
                final target = _ns(a, c.target);
                final wu = _ns(a, withUser);
                _wf.getMessagesByMessageStatusV2(
                    c.type,
                    target.ptr,
                    target.len,
                    c.line,
                    _i32Array(a, statuses),
                    statuses.length,
                    fromIndex,
                    direction,
                    count.abs(),
                    wu.ptr,
                    wu.len,
                    _cbString,
                    _cbError,
                    pObj,
                    0);
              }));
        }
      case 'getConversationsMessages':
        {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          final contentTypes = _intList(args, 'contentTypes');
          final fromIndex = _int(args, 'fromIndex');
          final count = _int(args, 'count');
          final withUser = _str(args, 'withUser');
          final direction = count > 0;
          return _awaitMessages((pObj) => using((a) {
                final wu = _ns(a, withUser);
                _wf.getMessagesExV2(
                    _i32Array(a, types),
                    types.length,
                    _i32Array(a, lines),
                    lines.length,
                    _i32Array(a, contentTypes),
                    contentTypes.length,
                    fromIndex,
                    direction,
                    count.abs(),
                    wu.ptr,
                    wu.len,
                    _cbString,
                    _cbError,
                    pObj,
                    0);
              }));
        }
      case 'getConversationsMessageByStatus':
        {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          final statuses = _intList(args, 'messageStatus');
          final fromIndex = _int(args, 'fromIndex');
          final count = _int(args, 'count');
          final withUser = _str(args, 'withUser');
          final direction = count > 0;
          return _awaitMessages((pObj) => using((a) {
                final wu = _ns(a, withUser);
                _wf.getMessagesEx2V2(
                    _i32Array(a, types),
                    types.length,
                    _i32Array(a, lines),
                    lines.length,
                    _i32Array(a, statuses),
                    statuses.length,
                    fromIndex,
                    direction,
                    count.abs(),
                    wu.ptr,
                    wu.len,
                    _cbString,
                    _cbError,
                    pObj,
                    0);
              }));
        }
      case 'getRemoteMessages':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onMessagesCallback',
              {'requestId': requestId, 'messages': _reversedJsonList(json)});
          final c = _conv(args);
          final contentTypes = _intList(args, 'contentTypes');
          using((a) {
            final target = _ns(a, c.target);
            _wf.getRemoteMessages(
                c.type,
                target.ptr,
                target.len,
                c.line,
                _i32Array(a, contentTypes),
                contentTypes.length,
                _int(args, 'beforeMessageUid'),
                _int(args, 'count'),
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'getRemoteMessage':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) {
            final v = _json(json);
            final message = v is List ? (v.isEmpty ? null : v.first) : v;
            if (message is Map) {
              _emit('onMessageCallback',
                  {'requestId': requestId, 'message': message});
            } else {
              _emit('onOperationFailure',
                  {'requestId': requestId, 'errorCode': -1});
            }
          };
          _wf.getRemoteMessage(_int(args, 'messageUid'), _cbString, _cbError,
              _reqPtr(requestId), 0);
          return null;
        }
      case 'getMessage':
        return _json(
            _outString((lp) => _wf.getMessage(_int(args, 'messageId'), lp)));
      case 'getMessageByUid':
        return _json(_outString(
            (lp) => _wf.getMessageByUid(_int(args, 'messageUid'), lp)));
      case 'searchMessages':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final keyword = _ns(a, _str(args, 'keyword'));
          final wu = _ns(a, _str(args, 'withUser'));
          return _reversedJsonList(_outString((lp) => _wf.searchMessage(
              c.type,
              target.ptr,
              target.len,
              c.line,
              keyword.ptr,
              keyword.len,
              _bool(args, 'order'),
              _int(args, 'limit'),
              _int(args, 'offset'),
              wu.ptr,
              wu.len,
              lp)));
        });
      case 'searchConversationsMessages':
        return using((a) {
          final types = _intList(args, 'types');
          final lines = _intList(args, 'lines');
          final contentTypes = _intList(args, 'contentTypes');
          final keyword = _ns(a, _str(args, 'keyword'));
          final wu = _ns(a, _str(args, 'withUser'));
          final count = _int(args, 'count');
          return _reversedJsonList(_outString((lp) => _wf.searchMessageEx2(
              _i32Array(a, types),
              types.length,
              _i32Array(a, lines),
              lines.length,
              _i32Array(a, contentTypes),
              contentTypes.length,
              keyword.ptr,
              keyword.len,
              _int(args, 'fromIndex'),
              count > 0,
              count.abs(),
              wu.ptr,
              wu.len,
              lp)));
        });

      // ---- 消息发送/操作 ----
      case 'sendMessage':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final content = _ns(a, _payloadJson(args['content'] as Map?));
          final toUsers = _nsArray(a, _strList(args, 'toUsers'));
          final lenPtr = a<Size>();
          final p = _wf.sendMessage(
              c.type,
              target.ptr,
              target.len,
              c.line,
              content.ptr,
              content.len,
              toUsers.ptrs,
              toUsers.lens,
              toUsers.count,
              _int(args, 'expireDuration'),
              _bridge.fn('wfc_on_send_message_success'),
              _bridge.fn('wfc_on_send_message_error'),
              _bridge.fn('wfc_on_send_message_prepared'),
              _bridge.fn('wfc_on_send_message_progress'),
              _bridge.fn('wfc_on_send_message_uploaded'),
              _reqPtr(_int(args, 'requestId')),
              0,
              lenPtr);
          return _json(_takeDllString(p, lenPtr.value));
        });
      case 'sendSavedMessage':
        return _wf.sendSavedMessage(
            _int(args, 'messageId'),
            _int(args, 'expireDuration'),
            _bridge.fn('wfc_on_send_message_success'),
            _bridge.fn('wfc_on_send_message_error'),
            _reqPtr(_int(args, 'requestId')),
            0);
      case 'cancelSendingMessage':
        return _wf.cancelSendingMessage(_int(args, 'messageId'));
      case 'recallMessage':
        _wf.recallMessage(_int(args, 'messageUid'), _cbVoid, _cbError,
            _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'uploadMedia':
        return using((a) {
          final fileName = _ns(a, _str(args, 'fileName'));
          final mediaData = args['mediaData'];
          final bytes = mediaData is Uint8List ? mediaData : Uint8List(0);
          final dataPtr = a<Uint8>(bytes.length + 1);
          dataPtr.asTypedList(bytes.length + 1)
            ..setAll(0, bytes)
            ..[bytes.length] = 0;
          _wf.uploadMedia(
              fileName.ptr,
              fileName.len,
              dataPtr.cast<Char>(),
              bytes.length,
              _int(args, 'mediaType'),
              _cbString,
              _cbError,
              _bridge.fn('wfc_on_upload_media_progress'),
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'uploadMediaFile':
        {
          final requestId = _int(args, 'requestId');
          final filePath = _str(args, 'filePath');
          final file = File(filePath);
          if (!file.existsSync()) {
            _emit('onOperationFailure', {
              'requestId': requestId,
              'errorCode': -1,
            });
            return null;
          }
          final bytes = file.readAsBytesSync();
          final name = path.basename(filePath);
          return using((a) {
            final fileName = _ns(a, name);
            final dataPtr = a<Uint8>(bytes.length + 1);
            dataPtr.asTypedList(bytes.length + 1)
              ..setAll(0, bytes)
              ..[bytes.length] = 0;
            _wf.uploadMedia(
                fileName.ptr,
                fileName.len,
                dataPtr.cast<Char>(),
                bytes.length,
                _int(args, 'mediaType'),
                _cbString,
                _cbError,
                _bridge.fn('wfc_on_upload_media_progress'),
                _reqPtr(requestId),
                0);
            return null;
          });
        }
      case 'getUploadUrl':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) {
            final m = _jsonMap(json);
            _emit('onGetUploadUrl', {
              'requestId': requestId,
              'uploadUrl': _str(m, 'uploadUrl'),
              'downloadUrl': _str(m, 'downloadUrl'),
              'backupUploadUrl': _str(m, 'backupUploadUrl'),
              'type': _int(m, 'type'),
            });
          };
          using((a) {
            final fileName = _ns(a, _str(args, 'fileName'));
            final contentType = _ns(a, _str(args, 'contentType'));
            _wf.getUploadUrl(fileName.ptr, fileName.len, _int(args, 'mediaType'),
                contentType.ptr, contentType.len, _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'isSupportBigFilesUpload':
        return _wf.isSupportBigFilesUpload();
      case 'isForceBigFilesUpload':
        return _wf.isForceBigFilesUpload();
      case 'deleteMessage':
        return _wf.deleteMessage(_int(args, 'messageId'));
      case 'batchDeleteMessages':
        return using((a) {
          final uids = _intList(args, 'messageUids');
          return _wf.batchDeleteMessages(_i64Array(a, uids), uids.length);
        });
      case 'deleteRemoteMessage':
        _wf.deleteRemoteMessage(_int(args, 'messageUid'), _cbVoid, _cbError,
            _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'clearMessages':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final before = _int(args, 'before');
          if (before <= 0) {
            _wf.clearMessages(c.type, target.ptr, target.len, c.line);
          } else {
            _wf.clearMessagesBefore(
                c.type, target.ptr, target.len, c.line, before);
          }
          return true;
        });
      case 'clearMessagesKeepLatest':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.clearMessagesKeep(
              c.type, target.ptr, target.len, c.line, _int(args, 'keepCount'));
          return true;
        });
      case 'clearRemoteConversationMessage':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          _wf.clearRemoteConversationMessage(c.type, target.ptr, target.len,
              c.line, _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'setMediaMessagePlayed':
        _wf.setMediaMessagePlayed(_int(args, 'messageId'));
        return null;
      case 'setMessageLocalExtra':
        return using((a) {
          final extra = _ns(a, _str(args, 'localExtra'));
          return _wf.setMessageLocalExtra(
              _int(args, 'messageId'), extra.ptr, extra.len);
        });
      case 'insertMessage':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          final sender = _ns(a, _str(args, 'sender'));
          final content = _ns(a, _payloadJson(args['content'] as Map?));
          final lenPtr = a<Size>();
          final p = _wf.insertMessage(
              c.type,
              target.ptr,
              target.len,
              c.line,
              sender.ptr,
              sender.len,
              content.ptr,
              content.len,
              _int(args, 'status'),
              _bool(args, 'notify'),
              _int(args, 'serverTime'),
              lenPtr);
          return _json(_takeDllString(p, lenPtr.value));
        });
      case 'updateMessage':
        return using((a) {
          final content = _ns(a, _payloadJson(args['content'] as Map?));
          _wf.updateMessage(_int(args, 'messageId'), content.ptr, content.len);
          return null;
        });
      case 'updateRemoteMessageContent':
        return using((a) {
          final content = _ns(a, _payloadJson(args['content'] as Map?));
          _wf.updateRemoteMessage(
              _int(args, 'messageUid'),
              content.ptr,
              content.len,
              _bool(args, 'distribute'),
              _bool(args, 'updateLocal'),
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'updateMessageStatus':
        _wf.updateMessageStatus(_int(args, 'messageId'), _int(args, 'status'));
        return null;
      case 'getMessageCount':
        return using((a) {
          final c = _conv(args);
          final target = _ns(a, c.target);
          return _wf.getMessageCount(c.type, target.ptr, target.len, c.line);
        });
      case 'getAuthorizedMediaUrl':
        {
          final requestId = _int(args, 'requestId');
          using((a) {
            final mediaPath = _ns(a, _str(args, 'mediaPath'));
            _wf.getAuthorizedMediaUrl(
                _int(args, 'messageUid'),
                _int(args, 'mediaType'),
                mediaPath.ptr,
                mediaPath.len,
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }

      // ---- 用户 ----
      case 'getUserInfo':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getUserInfo(userId.ptr,
              userId.len, _bool(args, 'refresh'), groupId.ptr, groupId.len,
              lp)));
        });
      case 'getUserInfos':
        return using((a) {
          final userIds = _nsArray(a, _strList(args, 'userIds'));
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getUserInfos(userIds.ptrs,
              userIds.lens, userIds.count, groupId.ptr, groupId.len, lp)));
        });
      case 'getUserInfoAsync':
        {
          final requestId = _int(args, 'requestId');
          final user = await _dispatch('getUserInfo', args);
          if (user is Map) {
            _emit('getUserInfoAsyncCallback',
                {'requestId': requestId, 'user': user});
          } else {
            _emit('onOperationFailure',
                {'requestId': requestId, 'errorCode': -1});
          }
          return null;
        }
      case 'searchUser':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onSearchUserResult',
              {'requestId': requestId, 'users': _jsonList(json)});
          using((a) {
            final keyword = _ns(a, _str(args, 'keyword'));
            final domainId = _str(args, 'domainId');
            if (domainId.isNotEmpty) {
              final domain = _ns(a, domainId);
              _wf.searchUserEx(keyword.ptr, keyword.len, domain.ptr, domain.len,
                  _int(args, 'searchType'), 0, _int(args, 'page'), _cbString, _cbError, _reqPtr(requestId), 0);
            } else {
              _wf.searchUser(keyword.ptr, keyword.len, _int(args, 'searchType'),
                  _int(args, 'page'), _cbString, _cbError, _reqPtr(requestId), 0);
            }
          });
          return null;
        }

      // ---- 好友 ----
      case 'isMyFriend':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _wf.isMyFriend(userId.ptr, userId.len);
        });
      case 'getMyFriendList':
        return _json(_outString(
            (lp) => _wf.getMyFriendList(_bool(args, 'refresh'), lp)));
      case 'searchFriends':
        return using((a) {
          final keyword = _ns(a, _str(args, 'keyword'));
          return _json(_outString(
              (lp) => _wf.searchFriends(keyword.ptr, keyword.len, lp)));
        });
      case 'getFriends':
        return _json(
            _outString((lp) => _wf.getFriendList(_bool(args, 'refresh'), lp)));
      case 'searchGroups':
        return using((a) {
          final keyword = _ns(a, _str(args, 'keyword'));
          return _json(_outString(
              (lp) => _wf.searchGroups(keyword.ptr, keyword.len, lp)));
        });
      case 'getIncommingFriendRequest':
        return _json(_outString((lp) => _wf.getIncommingFriendRequest(lp)));
      case 'getOutgoingFriendRequest':
        return _json(_outString((lp) => _wf.getOutgoingFriendRequest(lp)));
      case 'getFriendRequest':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _json(_outString((lp) => _wf.getFriendRequest(
              userId.ptr, userId.len, _int(args, 'direction') == 1, lp)));
        });
      case 'loadFriendRequestFromRemote':
        _wf.loadFriendRequestFromRemote();
        return null;
      case 'getUnreadFriendRequestStatus':
        return _wf.getUnreadFriendRequestStatus();
      case 'clearUnreadFriendRequestStatus':
        _wf.clearUnreadFriendRequestStatus();
        return true;
      case 'clearFriendRequest':
        return _wf.clearFriendRequest(
            _int(args, 'direction'), _int(args, 'beforeTime'));
      case 'deleteFriendRequest':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _wf.deleteFriendRequest(
              userId.ptr, userId.len, _int(args, 'direction'));
        });
      case 'deleteFriend':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          _wf.deleteFriend(userId.ptr, userId.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getFriendAlias':
        return using((a) {
          final friendId = _ns(a, _str(args, 'friendId'));
          return _outString(
              (lp) => _wf.getFriendAlias(friendId.ptr, friendId.len, lp));
        });
      case 'setFriendAlias':
        return using((a) {
          final friendId = _ns(a, _str(args, 'friendId'));
          final alias = _ns(a, _str(args, 'alias'));
          _wf.setFriendAlias(friendId.ptr, friendId.len, alias.ptr, alias.len,
              _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getFriendExtra':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _outString(
              (lp) => _wf.getFriendExtra(userId.ptr, userId.len, lp));
        });
      case 'sendFriendRequest':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          final reason = _ns(a, _str(args, 'reason'));
          final extra = _ns(a, _str(args, 'extra'));
          _wf.sendFriendRequest(userId.ptr, userId.len, reason.ptr, reason.len,
              extra.ptr, extra.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'handleFriendRequest':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          final extra = _ns(a, _str(args, 'extra'));
          _wf.handleFriendRequest(userId.ptr, userId.len,
              _bool(args, 'accept'), extra.ptr, extra.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'sendJoinGroupRequest':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final members = _nsArray(a, _strList(args, 'memberIds'));
          final reason = _ns(a, _str(args, 'reason'));
          final extra = _ns(a, _str(args, 'extra'));
          _wf.sendJoinGroupRequest(
              groupId.ptr,
              groupId.len,
              members.ptrs,
              members.lens,
              members.count,
              reason.ptr,
              reason.len,
              extra.ptr,
              extra.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'getJoinGroupRequests':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final memberId = _ns(a, _str(args, 'memberId'));
          return _jsonList(_outString((lp) => _wf.getJoinGroupRequests(
              groupId.ptr, groupId.len, memberId.ptr, memberId.len, _int(args, 'status'), lp)));
        });
      case 'handleJoinGroupRequest':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final memberId = _ns(a, _str(args, 'memberId'));
          final inviterId = _ns(a, _str(args, 'inviterId'));
          final memberExtra = _ns(a, _str(args, 'memberExtra'));
          _wf.handleJoinGroupRequest(
              groupId.ptr,
              groupId.len,
              memberId.ptr,
              memberId.len,
              inviterId.ptr,
              inviterId.len,
              _int(args, 'status'),
              memberExtra.ptr,
              memberExtra.len,
              _i32Array(a, _intList(args, 'lines')),
              _intList(args, 'lines').length,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'clearJoinGroupRequest':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final memberId = _ns(a, _str(args, 'memberId'));
          final inviterId = _ns(a, _str(args, 'inviterId'));
          return _wf.clearJoinGroupRequest(groupId.ptr, groupId.len, memberId.ptr,
              memberId.len, inviterId.ptr, inviterId.len);
        });
      case 'getAllJoinGroupRequestUnread':
        return _wf.getAllJoinGroupRequestUnread();
      case 'getJoinGroupRequestUnread':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _wf.getJoinGroupRequestUnread(groupId.ptr, groupId.len);
        });
      case 'clearJoinGroupRequestUnread':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          _wf.clearJoinGroupRequestUnread(groupId.ptr, groupId.len);
          return null;
        });
      case 'clearRemoteJoinGroupRequest':
        _wf.clearRemoteJoinGroupRequest(
            _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'isBlackListed':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _wf.isBlackListed(userId.ptr, userId.len);
        });
      case 'getBlackList':
        return _json(
            _outString((lp) => _wf.getBlackList(_bool(args, 'refresh'), lp)));
      case 'setBlackList':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          _wf.setBlackList(userId.ptr, userId.len,
              _bool(args, 'isBlackListed'), _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });

      // ---- 群组 ----
      case 'getGroupMembers':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getGroupMembers(
              groupId.ptr, groupId.len, _bool(args, 'refresh'), lp)));
        });
      case 'getGroupMembersByCount':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getGroupMembersByCount(
              groupId.ptr, groupId.len, _int(args, 'count'), lp)));
        });
      case 'getGroupMembersByTypes':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getGroupMembersByType(
              groupId.ptr, groupId.len, _int(args, 'memberType'), lp)));
        });
      case 'getGroupMembersAsync':
        {
          final requestId = _int(args, 'requestId');
          final members = await _dispatch('getGroupMembers', args);
          _emit('getGroupMembersAsyncCallback', {
            'requestId': requestId,
            'members': members is List ? members : [],
          });
          return null;
        }
      case 'getGroupInfo':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString((lp) => _wf.getGroupInfo(
              groupId.ptr, groupId.len, _bool(args, 'refresh'), lp)));
        });
      case 'getGroupInfos':
        return using((a) {
          final result = <dynamic>[];
          for (final groupId in _strList(args, 'groupIds')) {
            final ns = _ns(a, groupId);
            final info = _json(_outString(
                (lp) => _wf.getGroupInfo(ns.ptr, ns.len, false, lp)));
            if (info != null) result.add(info);
          }
          return result;
        });
      case 'getGroupInfoAsync':
        {
          final requestId = _int(args, 'requestId');
          final info = await _dispatch('getGroupInfo', args);
          if (info is Map) {
            _emit('getGroupInfoAsyncCallback',
                {'requestId': requestId, 'groupInfo': info});
          } else {
            _emit('onOperationFailure',
                {'requestId': requestId, 'errorCode': -1});
          }
          return null;
        }
      case 'getGroupMember':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final memberId = _ns(a, _str(args, 'memberId'));
          return _json(_outString((lp) => _wf.getGroupMember(
              groupId.ptr, groupId.len, memberId.ptr, memberId.len, lp)));
        });
      case 'createGroup':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onOperationStringSuccess',
              {'requestId': requestId, 'string': json});
          using((a) {
            final groupId = _ns(a, _str(args, 'groupId'));
            final groupName = _ns(a, _str(args, 'groupName'));
            final portrait = _ns(a, _str(args, 'groupPortrait'));
            final extra = _ns(a, '');
            final memberExtra = _ns(a, '');
            final members = _nsArray(a, _strList(args, 'groupMembers'));
            final lines = _linesOf(args);
            final notify = _ns(a, _notifyContentJson(args));
            _wf.createGroup(
                groupId.ptr,
                groupId.len,
                _int(args, 'type'),
                groupName.ptr,
                groupName.len,
                portrait.ptr,
                portrait.len,
                extra.ptr,
                extra.len,
                members.ptrs,
                members.lens,
                members.count,
                memberExtra.ptr,
                memberExtra.len,
                _i32Array(a, lines),
                lines.length,
                notify.ptr,
                notify.len,
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'addGroupMembers':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final members = _nsArray(a, _strList(args, 'groupMembers'));
          final memberExtra = _ns(a, '');
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.addMembers(
              groupId.ptr,
              groupId.len,
              members.ptrs,
              members.lens,
              members.count,
              memberExtra.ptr,
              memberExtra.len,
              _i32Array(a, lines),
              lines.length,
              notify.ptr,
              notify.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'kickoffGroupMembers':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final members = _nsArray(a, _strList(args, 'groupMembers'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.kickoffMembers(
              groupId.ptr,
              groupId.len,
              members.ptrs,
              members.lens,
              members.count,
              _i32Array(a, lines),
              lines.length,
              notify.ptr,
              notify.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'quitGroup':
      case 'quitGroupEx':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.quitGroup(groupId.ptr, groupId.len, _i32Array(a, lines),
              lines.length, notify.ptr, notify.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'dismissGroup':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.dismissGroup(groupId.ptr, groupId.len, _i32Array(a, lines),
              lines.length, notify.ptr, notify.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'modifyGroupInfo':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final value = _ns(a, _str(args, 'value'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.modifyGroupInfo(
              groupId.ptr,
              groupId.len,
              _int(args, 'modifyType'),
              value.ptr,
              value.len,
              _i32Array(a, lines),
              lines.length,
              notify.ptr,
              notify.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'modifyGroupAlias':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final alias = _ns(a, _str(args, 'newAlias'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.modifyGroupAlias(groupId.ptr, groupId.len, alias.ptr, alias.len,
              _i32Array(a, lines), lines.length, notify.ptr, notify.len,
              _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'modifyGroupMemberAlias':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final memberId = _ns(a, _str(args, 'memberId'));
          final alias = _ns(a, _str(args, 'newAlias'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.modifyGroupMemberAlias(
              groupId.ptr,
              groupId.len,
              memberId.ptr,
              memberId.len,
              alias.ptr,
              alias.len,
              _i32Array(a, lines),
              lines.length,
              notify.ptr,
              notify.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });
      case 'transferGroup':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final newOwner = _ns(a, _str(args, 'newOwner'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          _wf.transferGroup(groupId.ptr, groupId.len, newOwner.ptr,
              newOwner.len, _i32Array(a, lines), lines.length, notify.ptr,
              notify.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'setGroupManager':
      case 'muteGroupMember':
      case 'allowGroupMember':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final members = _nsArray(a, _strList(args, 'memberIds'));
          final lines = _linesOf(args);
          final notify = _ns(a, _notifyContentJson(args));
          final isSet = _bool(args, 'isSet');
          final pObj = _reqPtr(_int(args, 'requestId'));
          if (method == 'setGroupManager') {
            _wf.setGroupManager(groupId.ptr, groupId.len, isSet, members.ptrs,
                members.lens, members.count, _i32Array(a, lines), lines.length,
                notify.ptr, notify.len, _cbVoid, _cbError, pObj, 0);
          } else if (method == 'muteGroupMember') {
            _wf.muteGroupMember(groupId.ptr, groupId.len, isSet, members.ptrs,
                members.lens, members.count, _i32Array(a, lines), lines.length,
                notify.ptr, notify.len, _cbVoid, _cbError, pObj, 0);
          } else {
            _wf.allowGroupMember(groupId.ptr, groupId.len, isSet, members.ptrs,
                members.lens, members.count, _i32Array(a, lines), lines.length,
                notify.ptr, notify.len, _cbVoid, _cbError, pObj, 0);
          }
          return null;
        });
      case 'getGroupRemark':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _json(_outString(
              (lp) => _wf.getGroupRemark(groupId.ptr, groupId.len, lp)));
        });
      case 'setGroupRemark':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          final remark = _ns(a, _str(args, 'remark'));
          _wf.setGroupRemark(groupId.ptr, groupId.len, remark.ptr, remark.len,
              _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getFavGroups':
        return _json(_outString((lp) => _wf.getFavGroups(lp)));
      case 'isFavGroup':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _wf.isFavGroup(groupId.ptr, groupId.len);
        });
      case 'setFavGroup':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          _wf.setFavGroup(groupId.ptr, groupId.len, _bool(args, 'isFav'),
              _cbVoid, _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getMyGroups':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onOperationStringListSuccess',
              {'requestId': requestId, 'strings': _jsonList(json)});
          _wf.getMyGroups(_cbString, _cbError, _reqPtr(requestId), 0);
          return null;
        }
      case 'getCommonGroups':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onOperationStringListSuccess',
              {'requestId': requestId, 'strings': _jsonList(json)});
          using((a) {
            final userId = _ns(a, _str(args, 'userId'));
            _wf.getCommonGroups(userId.ptr, userId.len, _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }

      // ---- 用户设置 ----
      case 'getUserSetting':
        return using((a) {
          final key = _ns(a, _str(args, 'key'));
          return _outString((lp) =>
              _wf.getUserSetting(_int(args, 'scope'), key.ptr, key.len, lp));
        });
      case 'getUserSettings':
        return _jsonMap(
            _outString((lp) => _wf.getUserSettings(_int(args, 'scope'), lp)));
      case 'setUserSetting':
        return using((a) {
          final key = _ns(a, _str(args, 'key'));
          final value = _ns(a, _str(args, 'value'));
          _wf.setUserSetting(_int(args, 'scope'), key.ptr, key.len, value.ptr,
              value.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'modifyMyInfo':
        {
          final requestId = _int(args, 'requestId');
          final values = args['values'];
          if (values is Map) {
            using((a) {
              values.forEach((key, value) {
                final v = value?.toString() ?? '';
                if (v.isEmpty) return;
                final ns = _ns(a, v);
                _wf.modifyMyInfo((key as num).toInt(), ns.ptr, ns.len, _cbVoid,
                    _cbError, _reqPtr(requestId), 0);
              });
            });
          }
          return null;
        }
      case 'isGlobalSilent':
        return _wf.isGlobalSilent();
      case 'setGlobalSilent':
        _wf.setGlobalSilent(_bool(args, 'isSilent'), _cbVoid, _cbError,
            _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'isEnableSyncDraft':
        return _wf.isEnableSyncDraft();
      case 'isHiddenNotificationDetail':
        return _wf.isHiddenNotificationDetail();
      case 'setHiddenNotificationDetail':
        _wf.setHiddenNotificationDetail(_bool(args, 'isHidden'), _cbVoid,
            _cbError, _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'isHiddenGroupMemberName':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          return _wf.isHiddenGroupMemberName(groupId.ptr, groupId.len);
        });
      case 'setHiddenGroupMemberName':
        return using((a) {
          final groupId = _ns(a, _str(args, 'groupId'));
          _wf.setHiddenGroupMemberName(groupId.ptr, groupId.len,
              _bool(args, 'isHidden'), _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'isUserEnableReceipt':
        return _wf.isUserEnableReceipt();
      case 'setUserEnableReceipt':
        _wf.setUserEnableReceipt(_bool(args, 'isEnable'), _cbVoid, _cbError,
            _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'getFavUsers':
        return _json(_outString((lp) => _wf.getFavUsers(lp)));
      case 'isFavUser':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          return _wf.isFavUser(userId.ptr, userId.len);
        });
      case 'setFavUser':
        return using((a) {
          final userId = _ns(a, _str(args, 'userId'));
          _wf.setFavUser(userId.ptr, userId.len, _bool(args, 'isFav'), _cbVoid,
              _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });

      // ---- 聊天室 ----
      case 'joinChatroom':
        return using((a) {
          final chatroomId = _ns(a, _str(args, 'chatroomId'));
          _wf.joinChatroom(chatroomId.ptr, chatroomId.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'quitChatroom':
        return using((a) {
          final chatroomId = _ns(a, _str(args, 'chatroomId'));
          _wf.quitChatroom(chatroomId.ptr, chatroomId.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getChatroomInfo':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onGetChatroomInfoResult',
              {'requestId': requestId, 'chatroomInfo': _jsonMap(json)});
          using((a) {
            final chatroomId = _ns(a, _str(args, 'chatroomId'));
            _wf.getChatroomInfo(chatroomId.ptr, chatroomId.len,
                _int(args, 'updateDt'), _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'getChatroomMemberInfo':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onGetChatroomMemberInfoResult',
              {'requestId': requestId, 'chatroomMemberInfo': _jsonMap(json)});
          using((a) {
            final chatroomId = _ns(a, _str(args, 'chatroomId'));
            _wf.getChatroomMemberInfo(chatroomId.ptr, chatroomId.len,
                _int(args, 'maxCount', 30), _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'getJoinedChatroomId':
        return _outString((lp) => _wf.getJoinedChatroomId(lp));

      // ---- 频道 ----
      case 'createChannel':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onCreateChannelSuccess',
              {'requestId': requestId, 'channelInfo': _jsonMap(json)});
          using((a) {
            final name = _ns(a, _str(args, 'name'));
            final portrait = _ns(a, _str(args, 'portrait'));
            final desc = _ns(a, _str(args, 'desc'));
            final extra = _ns(a, _str(args, 'extra'));
            _wf.createChannel(name.ptr, name.len, portrait.ptr, portrait.len,
                desc.ptr, desc.len, extra.ptr, extra.len, _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'getChannelInfo':
        return using((a) {
          final channelId = _ns(a, _str(args, 'channelId'));
          return _json(_outString((lp) => _wf.getChannelInfo(
              channelId.ptr, channelId.len, _bool(args, 'refresh'), lp)));
        });
      case 'modifyChannelInfo':
        return using((a) {
          final channelId = _ns(a, _str(args, 'channelId'));
          final newValue = _ns(a, _str(args, 'newValue'));
          _wf.modifyChannelInfo(channelId.ptr, channelId.len,
              _int(args, 'type'), newValue.ptr, newValue.len, _cbVoid,
              _cbError, _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'searchChannel':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onSearchChannelResult',
              {'requestId': requestId, 'channelInfos': _jsonList(json)});
          using((a) {
            final keyword = _ns(a, _str(args, 'keyword'));
            _wf.searchChannel(keyword.ptr, keyword.len, _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'isListenedChannel':
        return using((a) {
          final channelId = _ns(a, _str(args, 'channelId'));
          return _wf.isListenedChannel(channelId.ptr, channelId.len);
        });
      case 'listenChannel':
        return using((a) {
          final channelId = _ns(a, _str(args, 'channelId'));
          _wf.listenChannel(channelId.ptr, channelId.len,
              _bool(args, 'listen'), _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'getMyChannels':
        return _json(_outString((lp) => _wf.getMyChannels(lp)));
      case 'getRemoteListenedChannels':
        {
          final requestId = _int(args, 'requestId');
          final channels =
              _jsonList(_outString((lp) => _wf.getListenedChannels(lp)));
          _emit('onOperationStringListSuccess',
              {'requestId': requestId, 'strings': channels});
          return null;
        }
      case 'destroyChannel':
        return using((a) {
          final channelId = _ns(a, _str(args, 'channelId'));
          _wf.destoryChannel(channelId.ptr, channelId.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });

      // ---- 在线状态 ----
      case 'getMyCustomState':
        return _jsonMap(_outString((lp) => _wf.getMyCustomState(lp)));
      case 'setMyCustomState':
        return using((a) {
          final state = jsonEncode({
            'state': _int(args, 'customState'),
            'text': _str(args, 'customText'),
          });
          final ns = _ns(a, state);
          _wf.setMyCustomState(ns.ptr, ns.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'watchOnlineState':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onWatchOnlineStateSuccess',
              {'requestId': requestId, 'states': _jsonList(json)});
          using((a) {
            final targets = _nsArray(a, _strList(args, 'targets'));
            _wf.watchOnlineState(
                _int(args, 'conversationType'),
                targets.ptrs,
                targets.lens,
                targets.count,
                _int(args, 'watchDuration'),
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'unwatchOnlineState':
        return using((a) {
          final targets = _nsArray(a, _strList(args, 'targets'));
          _wf.unwatchOnlineState(_int(args, 'conversationType'), targets.ptrs,
              targets.lens, targets.count, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'isEnableUserOnlineState':
        return _wf.isEnableUserOnlineState();

      // ---- 会议/文件/应用 ----
      case 'sendConferenceRequest':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit(
              'onSendConferenceRequestSuccess',
              {'requestId': requestId, 'error': 0, 'result': json});
          using((a) {
            final roomId = _ns(a, _str(args, 'roomId'));
            final request = _ns(a, _str(args, 'request'));
            final data = _ns(a, _str(args, 'data'));
            _wf.sendConferenceRequest(
                _int(args, 'sessionId'),
                roomId.ptr,
                roomId.len,
                request.ptr,
                request.len,
                _bool(args, 'advanced'),
                data.ptr,
                data.len,
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'getConversationFiles':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onFilesResult',
              {'requestId': requestId, 'files': _jsonList(json)});
          final c = _conv(args);
          using((a) {
            final target = _ns(a, c.target);
            final fromUser = _ns(a, _str(args, 'fromUser'));
            _wf.getConversationFiles(
                c.type,
                target.ptr,
                target.len,
                c.line,
                fromUser.ptr,
                fromUser.len,
                _int(args, 'beforeMessageUid'),
                _int(args, 'order'),
                _int(args, 'count'),
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'getMyFiles':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onFilesResult',
              {'requestId': requestId, 'files': _jsonList(json)});
          _wf.getMyFiles(_int(args, 'beforeMessageUid'), _int(args, 'order'),
              _int(args, 'count'), _cbString, _cbError, _reqPtr(requestId), 0);
          return null;
        }
      case 'deleteFileRecord':
        _wf.deleteFileRecord(_int(args, 'messageUid'), _cbVoid, _cbError,
            _reqPtr(_int(args, 'requestId')), 0);
        return null;
      case 'searchFiles':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onFilesResult',
              {'requestId': requestId, 'files': _jsonList(json)});
          final c = _conv(args);
          using((a) {
            final keyword = _ns(a, _str(args, 'keyword'));
            final target = _ns(a, c.target);
            final fromUser = _ns(a, _str(args, 'fromUser'));
            _wf.searchFiles(
                keyword.ptr,
                keyword.len,
                c.type,
                target.ptr,
                target.len,
                c.line,
                fromUser.ptr,
                fromUser.len,
                _int(args, 'beforeMessageUid'),
                _int(args, 'order'),
                _int(args, 'count'),
                _cbString,
                _cbError,
                _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'searchMyFiles':
        {
          final requestId = _int(args, 'requestId');
          _pendingString[requestId] = (json) => _emit('onFilesResult',
              {'requestId': requestId, 'files': _jsonList(json)});
          using((a) {
            final keyword = _ns(a, _str(args, 'keyword'));
            _wf.searchMyFiles(keyword.ptr, keyword.len,
                _int(args, 'beforeMessageUid'), _int(args, 'order'),
                _int(args, 'count'), _cbString, _cbError, _reqPtr(requestId),
                0);
          });
          return null;
        }
      case 'getAuthCode':
        {
          final requestId = _int(args, 'requestId');
          // 默认契约：onOperationStringSuccess 携带原始字符串，无需注册转换器。
          using((a) {
            final applicationId = _ns(a, _str(args, 'applicationId'));
            final host = _ns(a, _str(args, 'host'));
            _wf.getAuthCode(applicationId.ptr, applicationId.len,
                _int(args, 'type'), host.ptr, host.len, _cbString, _cbError,
                _reqPtr(requestId), 0);
          });
          return null;
        }
      case 'configApplication':
        return using((a) {
          final applicationId = _ns(a, _str(args, 'applicationId'));
          final nonce = _ns(a, _str(args, 'nonce'));
          final signature = _ns(a, _str(args, 'signature'));
          _wf.configApplication(
              applicationId.ptr,
              applicationId.len,
              _int(args, 'type'),
              _int(args, 'timestamp'),
              nonce.ptr,
              nonce.len,
              signature.ptr,
              signature.len,
              _cbVoid,
              _cbError,
              _reqPtr(_int(args, 'requestId')),
              0);
          return null;
        });

      // ---- 事务/服务器能力 ----
      case 'beginTransaction':
        return _wf.beginTransaction();
      case 'commitTransaction':
        return _wf.commitTransaction();
      case 'rollbackTransaction':
        return _wf.rollbackTransaction();
      case 'isCommercialServer':
        return _wf.isCommercialServer();
      case 'isReceiptEnabled':
        return _wf.isReceiptEnabled();
      case 'isGroupReceiptEnabled':
        return _wf.isGroupReceiptEnabled();
      case 'isGlobalDisableSyncDraft':
        return _wf.isGlobalDisableSyncDraft();

      // ---- 桌面端未实现的能力（与原生插件的兜底行为一致，显式留痕） ----
      case 'getWavData':
        _logStub(method, '空音频数据');
        return Uint8List(0);
      case 'getOnlineInfos':
        _logStub(method, '[]');
        return <dynamic>[];
      case 'isVoipNotificationSilent':
      case 'isNoDisturbing':
      case 'isMuteNotificationWhenPcOnline':
        _logStub(method, 'false');
        return false;
      case 'getUserOnlineState':
        // 返回 null，Dart 层回退到在线事件缓存。
        return null;
      case 'kickoffPCClient':
        _emit('onOperationVoidSuccess', {'requestId': _int(args, 'requestId')});
        return null;
      case 'setDefaultSilentWhenPcOnline':
      case 'setVoipNotificationSilent':
      case 'setEnableSyncDraft':
        // 桌面端原生库未单独暴露 setEnableSyncDraft，通过 setUserSetting 写入
        // Disable_Sync_Draft（scope=20）实现与移动端一致的行为。
        return using((a) {
          final key = _ns(a, '');
          final value = _ns(a, _bool(args, 'enable') ? '0' : '1');
          _wf.setUserSetting(UserSettingScope.Disable_Sync_Draft, key.ptr, key.len,
              value.ptr, value.len, _cbVoid, _cbError,
              _reqPtr(_int(args, 'requestId')), 0);
          return null;
        });
      case 'muteNotificationWhenPcOnline':
      case 'getNoDisturbingTimes':
      case 'setNoDisturbingTimes':
      case 'clearNoDisturbingTimes':
      case 'getMediaUploadUrl':
        return null;

      default:
        throw MissingPluginException(
            'No implementation found for method $method on channel imclient');
    }
  }

  static List<int> _linesOf(Map args) {
    final lines = _intList(args, 'notifyLines');
    return lines.isEmpty ? const [0] : lines;
  }
}

class _NS {
  const _NS(this.ptr, this.len);
  final Pointer<Char> ptr;
  final int len;
}

class _NSArray {
  const _NSArray(this.ptrs, this.lens, this.count);
  final Pointer<Pointer<Char>> ptrs;
  final Pointer<Size> lens;
  final int count;
}

class _Conv {
  const _Conv(this.type, this.target, this.line);
  final int type;
  final String target;
  final int line;
}

/// 与 wfc_dart_bridge.c 中的枚举保持一致。
class _BridgeTag {
  static const int connectionStatus = 1;
  static const int receiveMessage = 2;
  static const int recallMessage = 3;
  static const int deleteMessage = 4;
  static const int userInfoUpdated = 5;
  static const int groupInfoUpdated = 6;
  static const int groupMemberUpdated = 7;
  static const int friendListUpdated = 8;
  static const int friendRequestUpdated = 9;
  static const int settingUpdated = 10;
  static const int channelInfoUpdated = 11;
  static const int messageDelivered = 12;
  static const int messageReaded = 13;
  static const int joinGroupRequestUpdated = 14;
  static const int domainInfoUpdated = 15;

  static const int onlineEventUpdated = 16;

  static const int generalVoidSuccess = 20;
  static const int generalStringSuccess = 21;
  static const int generalError = 22;
  static const int sendMessageSuccess = 23;
  static const int sendMessagePrepared = 24;
  static const int sendMessageProgress = 25;
  static const int sendMessageUploaded = 26;
  static const int sendMessageError = 27;
  static const int uploadMediaProgress = 28;
  static const int connectedToServer = 29;
}

/// wfc_dart_bridge 导出符号绑定。
class _BridgeBindings {
  _BridgeBindings(this._lib);

  final DynamicLibrary _lib;

  late final int Function(Pointer<Void>) init = _lib.lookupFunction<
      IntPtr Function(Pointer<Void>),
      int Function(Pointer<Void>)>('wfc_dart_bridge_init');

  late final void Function(int) setPort = _lib.lookupFunction<
      Void Function(Int64), void Function(int)>('wfc_dart_bridge_set_port');

  final Map<String, Pointer<NativeFunction<dynamic>>> _cache = {};

  Pointer<NativeFunction<T>> fn<T extends Function>(String name) {
    return (_cache[name] ??= _lib.lookup<NativeFunction<T>>(name))
        as Pointer<NativeFunction<T>>;
  }
}
