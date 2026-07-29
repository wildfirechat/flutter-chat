import 'package:imclient/imclient_method_channel.dart';

import '../multi_window/proxy_imclient_channel.dart';

/// WebView 子窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// WebView 子窗口不连接 IM，所有 IM 调用都通过 [WindowEventChannel] 转发到
/// 主窗口执行。当前页面侧主要依赖 getAuthCode/configApplication/getUserInfo/
/// getUserInfos 这类接口，因此在这里声明对应方法表。
class WFWebViewWindowImclientChannel extends ProxyImclientChannel {
  static const String _tag = 'WFWebViewWindowImclientChannel';

  WFWebViewWindowImclientChannel()
      : super('wfWebView.imclient', tag: _tag, windowName: 'wfWebView') {
    forwardWithRequestId(
      'getAuthCode',
      ProxyImclientChannel.dispatchStringResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'appId': map['appId'],
          'appType': map['appType'],
          'host': map['host'],
        };
      },
    );
    forwardWithRequestId(
      'configApplication',
      ProxyImclientChannel.dispatchVoidResult,
      makeRequest: (args) {
        final map = args as Map<dynamic, dynamic>;
        return {
          'appId': map['applicationId'],
          'appType': map['appType'],
          'timestamp': map['timestamp'],
          'nonce': map['nonce'],
          'signature': map['signature'],
        };
      },
    );
    forwardSimple('getUserInfo');
    forwardSimple('getUserInfos');
  }
}
