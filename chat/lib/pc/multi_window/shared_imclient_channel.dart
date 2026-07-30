import 'proxy_imclient_channel.dart';
import 'window_event_channel.dart';

/// 所有 PC 子窗口共用的**唯一** IM 代理通道。
///
/// 取代此前每个窗口一份的 CallWindowImclientChannel /
/// MomentWindowImclientChannel / SearchWindowImclientChannel /
/// WFWebViewWindowImclientChannel:方法表、参数形状、结果分发只有一处定义,
/// 主窗口侧对应 MainImclientProxy 一处实现,事件名统一为 `im.<method>`。
///
/// **为什么合并。** 此前每个窗口自己声明方法表 + 自己写参数整形闭包 + 主窗口
/// 侧自己写 handler 和编码器,同一个 `getUserInfo` 存在四份实现。这套重复已经
/// 造成三次静默故障(全部实测确认):
///
/// 1. `MainWFWebViewProxy` 自带的 UserInfo 编码器主键写成 `'userId'`(应为
///    `'uid'`),`_convertProtoUserInfo` 直接返回 null;
/// 2. `ModelCodec.encodeGroupMember` 漏了 `'groupId'`,而 `GroupMember.groupId`
///    是 `late String`,群通话邀请成员时抛 TypeError;
/// 3. webview 的整形闭包把 `getAuthCode` 的键读成 `'appId'`/`'appType'`,
///    imclient 发的是 `'applicationId'`/`'type'`,于是工作台页面拿空
///    applicationId 去换认证码。
///
/// 三次都是"手写映射漏字段/错键名",不是逻辑错误——所以根治办法是让映射
/// **只有一份**,而不是把每一份都审一遍。
///
/// **参数一律透传,不做整形。** 主窗口侧 handler 按 imclient 的原始 args 键名
/// 读取,这样"子窗口传什么"和"主窗口读什么"共用同一份契约(即 imclient 自己的
/// 参数定义),没有第三套键名可以写错。唯一的例外是 [sendMessage],它要额外带上
/// 发起窗口的 id(见下)。
///
/// **requestId 不需要跨窗口命名空间。** 回调式接口在主窗口侧经 `ProxyCompleter`
/// 绕回类型化 `Imclient.xxx` API,由主 isolate 重新分配自己的 requestId,
/// 回调闭包**词法捕获**子窗口的 requestId——闭包本身就是那张映射表。
/// (只有把子窗口 requestId 原样喂给原生的"裸透传"方案才需要命名空间,那条路
/// 还得先把 `ImclientPlatform.init` 里那 578 行 dispatch switch 抽成公开方法。)
///
/// [sendMessage] 是唯一需要知道调用方的接口:它的成功/失败是在服务器 ack 之后
/// 才回来的,必须回传给**发起的那个**窗口,所以在 args 里带上 [windowId]
/// (键 `_windowId`,下划线前缀避免与 imclient 自己的参数撞名)。
class SharedImclientChannel extends ProxyImclientChannel {
  static const String _tag = 'SharedImclientChannel';

  /// 发起窗口的 id,仅 [sendMessage] 需要(结果按它回传)。
  final int windowId;

  SharedImclientChannel({
    required this.windowId,
    required String windowName,
  }) : super(kSharedImEventPrefix, tag: _tag, windowName: windowName) {
    // ---------------------------------------------------------- 无副作用查询
    forwardSimple('getUserInfo');
    forwardSimple('getUserInfos');
    forwardSimple('getGroupMembers');
    forwardSimple('currentUserId');
    forwardSimple('clientId');
    forwardSimple('connectionStatus');
    forwardSimple('isLogined');
    forwardSimple('serverDeltaTime');

    // ---------------------------------------------------------- 消息读取
    forwardSimple('getMessages');
    forwardSimple('searchMessages');
    forwardSimple('getMessagesByTimestamp');
    forwardSimple('getMessageCountByDay');
    forwardSimple('getMessageByUid');
    forwardSimple('getConversationsMessageByStatus');

    // ---------------------------------------------------------- 会话未读
    forwardSimple('getConversationsUnreadCount');
    forwardSimple('clearConversationsUnreadStatus');

    // ---------------------------------------------------------- 消息写入
    // 返回值是主窗口本地入库的 message(与移动端 sendMessage 返回语义一致);
    // 成功/失败在服务器 ack 后经 `im.onSendMessageResult` 异步回传本窗口。
    forward('sendMessage', reshapeArgs: (args) {
      return {
        ...(args as Map<dynamic, dynamic>),
        _kWindowIdKey: windowId,
      };
    });
    forwardSimple('updateMessage');

    // ---------------------------------------------------------- 聊天室
    forwardSimple('joinChatroom');
    forwardSimple('quitChatroom');

    // ---------------------------------------------------------- 回调式接口
    forwardWithRequestId(
        'sendConferenceRequest', ProxyImclientChannel.dispatchConferenceResult);
    forwardWithRequestId(
        'sendMomentsRequest', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'uploadMedia', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'uploadMediaFile', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'getConversationFiles', ProxyImclientChannel.dispatchFilesResult);
    forwardWithRequestId(
        'searchFiles', ProxyImclientChannel.dispatchFilesResult);
    forwardWithRequestId(
        'getAuthorizedMediaUrl', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'deleteFileRecord', ProxyImclientChannel.dispatchVoidResult);
    forwardWithRequestId(
        'getAuthCode', ProxyImclientChannel.dispatchStringResult);
    forwardWithRequestId(
        'configApplication', ProxyImclientChannel.dispatchVoidResult);
  }

  /// 主窗口回传发送结果的事件名。
  static const String sendMessageResultEvent =
      '$kSharedImEventPrefix.onSendMessageResult';

  /// args 中携带发起窗口 id 的键。
  static const String _kWindowIdKey = '_windowId';

  /// 从 sendMessage 的 args 中取出发起窗口 id(主窗口侧使用)。
  static int? windowIdOf(dynamic args) =>
      (args is Map) ? args[_kWindowIdKey] as int? : null;

  /// 本窗口需要注册到 [WindowEventChannel] 的 handler(由
  /// `SubWindowAppBase` 合并进 eventHandlers)。
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        sendMessageResultEvent: (args) async {
          ProxyImclientChannel.dispatchSendMessageResult(args);
          return null;
        },
      };
}
