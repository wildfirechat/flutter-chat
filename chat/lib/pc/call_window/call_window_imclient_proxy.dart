import 'dart:convert';

import 'package:imclient/imclient_method_channel.dart';

import '../multi_window/proxy_imclient_channel.dart';
import 'call_window_events.dart';

/// Call 窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 所有 IM 调用都通过 [WindowEventChannel] 转发到主窗口执行，
/// 主窗口执行真实 [Imclient] 后再把结果返回。方法表在构造中声明,
/// 通用转发逻辑见 [ProxyImclientChannel]。
///
/// 对于 [sendMessage] 这类带异步回调的调用，回调仍注册在
/// [ImclientPlatform] 的既有 requestId 映射里;主窗口拿到服务器
/// ack/失败后经 `voip.sendMessageResult` 事件回传,由
/// [handleSendMessageResult] 走 [ImclientPlatform.dispatchSendMessageResult]
/// 统一触发回调并清理,与移动端 onSendMessageSuccess/Failure 语义一致。
class CallWindowImclientChannel extends ProxyImclientChannel {
  static const String _tag = 'CallWindowImclientChannel';

  CallWindowImclientChannel()
      : super('imclient', tag: _tag, windowName: 'call') {
    // 返回值只是主窗口本地入库的 message(与移动端 sendMessage 的返回语义一致);
    // 成功/失败回调由主窗口在服务器 ack 后经 sendMessageResult 事件异步回传。
    forward('sendMessage', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {
        'requestId': map['requestId'] as int,
        'conversation': map['conversation'],
        'content': map['content'],
        'toUsers': (map['toUsers'] as List?)?.cast<String>(),
        'expireDuration': map['expireDuration'] as int? ?? 0,
      };
    });
    forwardWithRequestId(
      'sendConferenceRequest',
      _dispatchConferenceRequestResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'requestId': map['requestId'] as int,
          'sessionId': map['sessionId'] as int,
          'roomId': map['roomId'] as String,
          'request': map['request'] as String,
          'advanced': map['advanced'] as bool? ?? false,
          'data': map['data'] as String? ?? '',
        };
      },
    );
    // 方法名与事件名不一致(updateMessage → imclient.updateMessageContent)。
    forward(
      'updateMessage',
      event: MainWindowEvents.updateMessageContent,
      reshapeArgs: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'messageId': map['messageId'] as int,
          'content': map['content'],
        };
      },
    );
    forward('getMessageByUid', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {'messageUid': map['messageUid'] as int};
    });
    forward('getUserInfo', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {
        'userId': map['userId'] as String,
        'refresh': map['refresh'] as bool? ?? false,
      };
    });
    forward('getUserInfos', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {
        'userIds': (map['userIds'] as List).cast<String>(),
        'groupId': map['groupId'] as String?,
      };
    });
    forward('getGroupMembers', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {
        'groupId': map['groupId'] as String,
        'refresh': map['refresh'] as bool? ?? false,
      };
    });
    forward('joinChatroom', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {'chatroomId': map['chatroomId'] as String};
    });
    forward('quitChatroom', reshapeArgs: (args) {
      final map = args as Map<dynamic, dynamic>;
      return {'chatroomId': map['chatroomId'] as String};
    });
    forwardSimple('currentUserId');
    forwardSimple('clientId');
    forwardSimple('connectionStatus');
    forwardSimple('isLogined');
    forwardSimple('serverDeltaTime');
  }

  /// 主窗口经 `voip.sendMessageResult` 回传的发送结果。
  void handleSendMessageResult(dynamic args) {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int?;
    if (requestId == null) return;
    ImclientPlatform.dispatchSendMessageResult(
      requestId,
      map['errorCode'] as int? ?? 0,
      messageUid: map['messageUid'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  /// sendConferenceRequest 结果回传:主窗口返回 {errorCode, result},
  /// result 可能不是 String(如 Map),按既有语义统一成字符串后分发。
  static void _dispatchConferenceRequestResult(int requestId, dynamic result) {
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? 0) : 0;
    final raw = (result is Map) ? result['result'] : null;
    final String payload;
    if (raw == null) {
      payload = '';
    } else if (raw is String) {
      payload = raw;
    } else {
      payload = jsonEncode(raw);
    }
    ImclientPlatform.dispatchConferenceRequestResult(requestId, errorCode, payload);
  }
}
