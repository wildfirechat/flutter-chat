/// 野火朋友圈组件库（SDK + UI，原 momentclient 与 momentkit 合并）。
///
/// 纯 Dart 实现，数据层在 `client/` 子目录（[MomentClient]），UI 在 `src/`。
/// 依赖 [imclient] 提供用户信息与媒体上传能力，因此同时支持
/// Android/iOS/鸿蒙/Windows/macOS/Linux。
///
/// 用法：
/// ```dart
/// // 应用启动时（IM 初始化之后）：
/// MomentClient.init((comment) {}, (feed) {});
/// MomentKit.configure(mediaPicker: myPicker);
///
/// // 打开朋友圈首页：
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedListPage()));
/// ```
library moment;

export 'src/moment_config.dart';
export 'src/moment_media_picker.dart';
export 'src/moment_user_cache.dart';
export 'src/moment_time.dart';
export 'src/feed_list_page.dart';
export 'src/feed_detail_page.dart';
export 'src/feed_messages_page.dart';
export 'src/publish_feed_page.dart';
export 'src/visible_scope_page.dart';
