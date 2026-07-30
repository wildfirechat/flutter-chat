import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/theme/app_typography.dart';

/// 微信式应用内相册选图(仅 Android/iOS,photo_manager 无桌面/ohos 实现)。
/// 返回选中的图片文件;取消返回空列表;相册权限被拒时提示并引导到系统设置。
///
/// 向微信看齐的两处行为:
/// - [showTakePhotoEntry] 控制网格首格的"拍摄"入口(拍完确认后直接作为选中
///   结果返回)。会话输入扩展的相册不显示,换头像等场景才显示。
/// - [maxAssets] 为 1 时进入单选模式:点图即选中返回,不显示 checkbox 与底栏。
Future<List<File>> pickImagesWithWfAssetPicker(
  BuildContext context, {
  required int maxAssets,
  bool showTakePhotoEntry = false,
}) async {
  // 依赖 context 的取值都放在 await 之前。
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  // 保持选择器默认的微信式暗色外观,仅把强调色(发送/确定按钮、选中角标)换成我们的主题色
  final ThemeData pickerTheme = AssetPicker.themeData(context.colors.accent);
  final AssetPickerTextDelegate textDelegate =
      assetPickerTextDelegateFromLocale(Localizations.localeOf(context));
  // 只申请图片相关权限,不连带视频
  const PermissionRequestOption permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );
  try {
    final PermissionState ps =
        await AssetPicker.permissionCheck(requestOption: permissionOption);
    if (!context.mounted) {
      return const [];
    }
    final List<AssetEntity>? assets = await AssetPicker.pickAssetsWithDelegate(
      context,
      delegate: WfAssetPickerBuilderDelegate(
        provider: DefaultAssetPickerProvider(
          maxAssets: maxAssets,
          requestType: RequestType.image,
        ),
        initialPermission: ps,
        pickerTheme: pickerTheme,
        textDelegate: textDelegate,
        // 单选禁用预览:点图即选中返回,checkbox 与底栏都不出现
        specialPickerType: maxAssets == 1 ? SpecialPickerType.noPreview : null,
        specialItemPosition: showTakePhotoEntry
            ? SpecialItemPosition.prepend
            : SpecialItemPosition.none,
        specialItemBuilder: showTakePhotoEntry
            ? (BuildContext context, AssetPathEntity? path, int length) =>
                _buildTakePhotoItem(context, path, l10n)
            : null,
      ),
      permissionRequestOption: permissionOption,
    );
    if (assets == null || assets.isEmpty) {
      return const [];
    }
    final List<File> files = [];
    for (final AssetEntity asset in assets) {
      final File? file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }
    return files;
  } on StateError {
    // 相册权限被拒绝,提示并引导到系统设置
    showToast(msg: l10n.albumPermissionDenied);
    PhotoManager.openSetting();
    return const [];
  }
}

/// 相册网格首格的"拍摄"入口:进应用内相机拍照,确认后关闭选择器并把照片作为结果返回
Widget? _buildTakePhotoItem(
    BuildContext context, AssetPathEntity? path, AppLocalizations l10n) {
  // 只在"最近项目/全部"相册里展示,进入具体相册时不显示
  if (path != null && !path.isAll) {
    return null;
  }
  return Semantics(
    label: l10n.takePhoto,
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final AssetEntity? entity = await CameraPicker.pickFromCamera(
          context,
          pickerConfig:
              const CameraPickerConfig(resolutionPreset: ResolutionPreset.high),
        );
        if (entity == null || !context.mounted) {
          return;
        }
        Navigator.of(context).pop(<AssetEntity>[entity]);
      },
      // 选择器固定微信式暗色外观,这里的颜色与之配套,不走 app_colors
      child: ColoredBox(
        color: const Color(0xFF2E2E2E),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              l10n.takePhoto,
              style: AppText.xs.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 相册选择器的定制 delegate:加高底部操作栏(预览/确定),向微信的比例看齐。
/// 主题色通过构造参数 [pickerTheme] 传入,取值 context.colors.accent。
class WfAssetPickerBuilderDelegate extends DefaultAssetPickerBuilderDelegate {
  WfAssetPickerBuilderDelegate({
    required super.provider,
    required super.initialPermission,
    super.pickerTheme,
    super.textDelegate,
    super.specialPickerType,
    super.specialItemPosition,
    super.specialItemBuilder,
  });

  // 默认值 kToolbarHeight / 1.1 ≈ 51,偏矮;微信约为 56~60
  @override
  double get bottomActionBarHeight => 60;
}
