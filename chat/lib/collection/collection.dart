/// 群接龙功能库
/// 
/// 提供群接龙的完整功能实现，包括：
/// - 发起接龙
/// - 参与接龙
/// - 查看接龙详情
/// - 接龙消息展示
/// 
/// 配置方法：
/// 在 Config.collectionServerAddress 中配置接龙服务地址，
/// 配置后群聊插件面板会自动显示接龙入口。
///
/// 使用示例：
/// ```dart
/// if (CollectionService.isAvailable) {
///   final collection = await CollectionService.getCollection(id, groupId);
/// }
/// ```

export 'collection_model.dart';
export 'collection_service.dart' show CollectionService, CollectionException;
export 'collection_detail_screen.dart';
export 'create_collection_screen.dart';
export 'collection_icon.dart';
