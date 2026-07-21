/// 野火朋友圈 UI 组件库。
///
/// 纯 Dart 实现，依赖 [momentclient] 作为数据层、[imclient] 提供用户信息与
/// 媒体上传能力，因此同时支持 Android/iOS/鸿蒙/Windows/macOS/Linux。
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
library momentkit;

export 'src/moment_config.dart';
export 'src/moment_media_picker.dart';
export 'src/moment_user_cache.dart';
export 'src/moment_time.dart';
export 'src/feed_list_page.dart';
export 'src/feed_detail_page.dart';
export 'src/feed_messages_page.dart';
export 'src/publish_feed_page.dart';
export 'src/visible_scope_page.dart';
