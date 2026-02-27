/// 群投票功能库
///
/// 提供群投票的完整功能实现，包括：
/// - 发起投票
/// - 参与投票
/// - 查看投票详情
/// - 投票消息展示
///
/// 配置方法：
/// 在 Config.POLL_SERVER_ADDRESS 中配置投票服务地址，
/// 配置后群聊插件面板会自动显示投票入口。
///
/// 使用示例：
/// ```dart
/// if (PollService.isAvailable) {
///   final poll = await PollService.getPoll(pollId);
/// }
/// ```

export 'poll_model.dart';
export 'poll_service.dart' show PollService, PollException;
export 'poll_detail_screen.dart';
export 'create_poll_screen.dart';
export 'poll_home_screen.dart';
export 'poll_list_screen.dart';
