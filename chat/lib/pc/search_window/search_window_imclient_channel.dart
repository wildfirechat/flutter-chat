import 'package:imclient/imclient_method_channel.dart';

import '../multi_window/proxy_imclient_channel.dart';

/// 会话内搜索窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 搜索窗口不连接 IM，所有 IM 调用都通过 [WindowEventChannel] 转发到主窗口
/// 执行，与朋友圈窗口的 [MomentWindowImclientChannel] 同构。
/// 方法表在构造中声明,通用转发逻辑见 [ProxyImclientChannel]。
///
/// 返回值式接口（getMessages/searchMessages 等）直接回传主窗口的执行结果；
/// 回调式接口（文件记录、授权 URL 等）沿用 requestId + 回调映射模式：
/// 主窗口执行后经 IPC 返回 {errorCode, ...}，这里按原生回调事件的既有语义
/// 走 [ImclientPlatform] 的 dispatch 方法触发回调并清理。
class SearchWindowImclientChannel extends ProxyImclientChannel {
  static const String _tag = 'SearchWindowImclientChannel';

  SearchWindowImclientChannel()
      : super('search.imclient', tag: _tag, windowName: 'search') {
    forwardSimple('getMessages');
    forwardSimple('searchMessages');
    forwardSimple('getMessagesByTimestamp');
    forwardSimple('getMessageCountByDay');
    forwardSimple('getUserInfo');
    forwardWithRequestId(
        'getConversationFiles', ProxyImclientChannel.dispatchFilesResult);
    forwardWithRequestId(
        'searchFiles', ProxyImclientChannel.dispatchFilesResult);
    forwardWithRequestId(
        'getAuthorizedMediaUrl', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'deleteFileRecord', ProxyImclientChannel.dispatchVoidResult);
  }
}
