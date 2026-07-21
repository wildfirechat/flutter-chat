import 'moment_media_picker.dart';

/// momentkit 全局配置。
///
/// 宿主 App 在启动时通过 [MomentKit.configure] 注入平台能力（相册选择器、
/// 联系人选择器），未注入时使用内置默认实现或禁用对应功能。
class MomentKit {
  MomentKit._();

  /// 相册/视频选择器。默认使用 file_picker（移动端走系统选择器，
  /// 桌面端走文件对话框），宿主可注入体验更好的实现（如 wechat_assets_picker）。
  static MomentMediaPicker mediaPicker = defaultMomentMediaPicker;

  /// 联系人选择器（“提醒谁看”/“部分可见”选人用），返回选中的 userId 列表。
  /// 默认 null：发布页不展示这两个入口。
  static MomentContactPicker? contactPicker;

  static void configure({
    MomentMediaPicker? mediaPicker,
    MomentContactPicker? contactPicker,
  }) {
    if (mediaPicker != null) MomentKit.mediaPicker = mediaPicker;
    if (contactPicker != null) MomentKit.contactPicker = contactPicker;
  }
}
