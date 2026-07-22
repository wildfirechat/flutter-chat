import 'package:imclient/imclient_method_channel.dart';

import '../multi_window/proxy_imclient_channel.dart';

/// 朋友圈窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 朋友圈窗口不连接 IM，所有 IM 调用都通过 [WindowEventChannel] 转发到主窗口
/// 执行，与 Call 窗口的 [CallWindowImclientChannel] 同构。
/// 方法表在构造中声明,通用转发逻辑见 [ProxyImclientChannel]。
///
/// sendMomentsRequest/uploadMedia/uploadMediaFile 使用 requestId + 回调映射
/// 模式:主窗口执行后返回 {errorCode, result},这里按
/// onOperationStringSuccess/Failure 的既有语义触发回调并清理。
/// uploadMedia 只回传最终 remoteUrl,忽略进度。
class MomentWindowImclientChannel extends ProxyImclientChannel {
  static const String _tag = 'MomentWindowImclientChannel';

  MomentWindowImclientChannel()
      : super('moment.imclient', tag: _tag, windowName: 'moment') {
    forwardWithRequestId(
      'sendMomentsRequest',
      ProxyImclientChannel.dispatchStringResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'requestId': map['requestId'] as int,
          'path': map['path'],
          'data': map['data'],
        };
      },
    );
    forwardSimple('getUserInfo');
    forwardSimple('getUserInfos');
    forwardSimple('getConversationsMessageByStatus');
    forwardSimple('getConversationsUnreadCount');
    forwardSimple('clearConversationsUnreadStatus');
    forwardWithRequestId(
      'uploadMedia',
      ProxyImclientChannel.dispatchStringResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'requestId': map['requestId'] as int,
          'fileName': map['fileName'],
          'mediaData': map['mediaData'],
          'mediaType': map['mediaType'],
        };
      },
    );
    forwardWithRequestId(
      'uploadMediaFile',
      ProxyImclientChannel.dispatchStringResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'requestId': map['requestId'] as int,
          'filePath': map['filePath'],
          'mediaType': map['mediaType'],
        };
      },
    );
    forwardSimple('serverDeltaTime');
  }
}
