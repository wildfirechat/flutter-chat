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

/// Call 窗口 → 主窗口 的事件名。
class MainWindowEvents {
  /// Imclient.sendMessage / sendConversationMessage。
  static const String sendMessage = 'imclient.sendMessage';

  /// Imclient.sendConferenceRequest。
  static const String sendConferenceRequest = 'imclient.sendConferenceRequest';

  /// Imclient.updateMessageContent。
  static const String updateMessageContent = 'imclient.updateMessageContent';

  /// Imclient.getMessageByUid。
  static const String getMessageByUid = 'imclient.getMessageByUid';

  /// Imclient.getUserInfo。
  static const String getUserInfo = 'imclient.getUserInfo';

  /// Imclient.getUserInfos。
  static const String getUserInfos = 'imclient.getUserInfos';

  /// Imclient.getGroupMembers。
  static const String getGroupMembers = 'imclient.getGroupMembers';

  /// Imclient.joinChatroom。
  static const String joinChatroom = 'imclient.joinChatroom';

  /// Imclient.quitChatroom。
  static const String quitChatroom = 'imclient.quitChatroom';

  /// Imclient.currentUserId。
  static const String currentUserId = 'imclient.currentUserId';

  /// Imclient.clientId。
  static const String clientId = 'imclient.clientId';

  /// Imclient.connectionStatus。
  static const String connectionStatus = 'imclient.connectionStatus';

  /// Imclient.isLogined。
  static const String isLogined = 'imclient.isLogined';

  /// Imclient.serverDeltaTime。
  static const String serverDeltaTime = 'imclient.serverDeltaTime';

  /// 通话窗口状态变化（可选）。
  static const String voipStatusChanged = 'voip.statusChanged';

  /// 通话窗口关闭。
  static const String windowClosed = 'voip.windowClosed';
}
