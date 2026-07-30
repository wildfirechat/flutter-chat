/// 主窗口 → Call 窗口 的事件名。
class CallWindowEvents {
  /// 转发收到的 IM 消息。
  static const String message = 'voip.message';

  /// 转发会议事件。
  static const String conferenceEvent = 'voip.conferenceEvent';

  /// 转发 IM 连接状态变化。
  static const String connectionStatus = 'voip.connectionStatus';

  /// 回传 sendMessage 的服务器 ack/失败结果(requestId/errorCode/messageUid/timestamp)。
  static const String sendMessageResult = 'voip.sendMessageResult';

  /// 主动发起单人/多人通话。
  static const String startCall = 'voip.startCall';

  /// 主动创建会议。
  static const String startConference = 'voip.startConference';

  /// 主动加入会议。
  static const String joinConference = 'voip.joinConference';
}

/// Call 窗口 → 主窗口 的事件名（仅窗口生命周期）。
///
/// 通话窗口的 IM 调用已全部并入共享域 `im.*`（见 multi_window/
/// shared_imclient_channel.dart + main_imclient_proxy.dart），所有子窗口共用
/// 一套 proxy + 一套 channel，这里只剩通话窗特有的窗口状态通知。
class MainWindowEvents {
  /// 通话窗口状态变化（`{status:'ready'/'ended', windowId}`）。
  /// 通话窗的「就绪」通知走它而不是公共层的 `<kind>.ready`。
  static const String voipStatusChanged = 'voip.statusChanged';

  /// 通话窗口关闭。
  static const String windowClosed = 'voip.windowClosed';
}
