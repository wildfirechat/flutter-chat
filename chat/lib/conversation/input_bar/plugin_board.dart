import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/conversation/input_bar/wf_asset_picker_delegate.dart';
import 'package:provider/provider.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/collection/create_collection_screen.dart';
import 'package:chat/collection/collection_icon.dart';
import 'package:chat/poll/poll_home_screen.dart';
import 'package:chat/poll/poll_icon.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/screenshot_service.dart';

class _PluginItem {
  /// 图标资源；接龙/投票/截屏用矢量绘制，没有对应图片，故可空。
  final String? iconPath;
  final String key;

  _PluginItem(this.iconPath, this.key);
}

class PluginBoard extends StatelessWidget {
  const PluginBoard(this.conversation, {super.key, this.height});

  static const int _maxImagePickCount = 9;

  final Conversation conversation;
  final double? height;

  List<_PluginItem> _getPluginItems() {
    final items = [
      _PluginItem('assets/images/input/album.png', "album"),
      // 截图依赖 flameshot,仅原生桌面可用(鸿蒙电脑无此能力)
      if (WfcPlatform.isNativeDesktop) _PluginItem(null, "screenshot"),
      if (!isDesktopShell)
        _PluginItem('assets/images/input/camera.png', "camera"),
      if (!isDesktopShell) _PluginItem('assets/images/input/call.png', "call"),
      if (!isDesktopShell)
        _PluginItem('assets/images/input/location.png', "location"),
      _PluginItem('assets/images/input/file.png', "file"),
      _PluginItem('assets/images/input/card.png', "card"),
    ];

    // 群接龙仅在群组中且配置了服务地址时显示
    if (conversation.conversationType == ConversationType.Group &&
        Config.collectionServerAddress != null &&
        Config.collectionServerAddress!.isNotEmpty) {
      items.add(_PluginItem(null, "collection"));
    }

    // 群投票仅在群组中且配置了服务地址时显示
    if (conversation.conversationType == ConversationType.Group &&
        Config.pollServerAddress != null &&
        Config.pollServerAddress!.isNotEmpty) {
      items.add(_PluginItem(null, "poll"));
    }

    return items;
  }

  String _getPluginTitle(BuildContext context, String titleKey) {
    final l10n = AppLocalizations.of(context)!;
    switch (titleKey) {
      case "album":
        return l10n.albumPicker;
      case "camera":
        return l10n.cameraCapture;
      case "call":
        return l10n.videoCallAction;
      case "location":
        return l10n.location;
      case "file":
        return l10n.filePicker;
      case "card":
        return l10n.businessCard;
      case "screenshot":
        return l10n.screenshotTool;
      case "collection":
        return l10n.collection;
      case "poll":
        return l10n.poll;
      default:
        return titleKey;
    }
  }

  Widget _pluginItemWidget(BuildContext context, _PluginItem item) {
    final double itemWidth =
        LayoutScale.watchScale(context, 64, cap: LayoutScale.iconCap);
    return GestureDetector(
      onTap: () => _onClickItem(context, item.key),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIcon(context, item, itemWidth),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              _getPluginTitle(context, item.key),
              textAlign: TextAlign.center,
              // 单行省略:「视频通话」这类较长文案不能把格子撑得比别人高
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.xs.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 统一的扩展项图标：主题色圆角底板 + 居中字形。
  ///
  /// 底板一律在这里画，图片资源只提供透明字形 —— 早先的 png 把白色底板烤进了图片，
  /// 暗色模式下就是一块白斑，且和接龙/投票这些矢量图标的底板对不上。
  Widget _buildIcon(BuildContext context, _PluginItem item, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(child: _buildGlyph(context, item, size)),
    );
  }

  /// 字形按「占底板约 44%」对齐，各图标的留白比例不同，故传入的尺寸也不同：
  /// - png 自带约 44% 的留白，铺满底板即可；
  /// - 矢量图标画在 24 视口里、笔画范围 10 单位（≈42%），同样铺满底板；
  /// - Material 图标的字形约占字号的 83%，故取一半。
  Widget _buildGlyph(BuildContext context, _PluginItem item, double size) {
    final Color color = context.colors.iconSecondary;
    switch (item.key) {
      case 'collection':
        return CollectionIcon(size: size, color: color);
      case 'poll':
        return PollIcon(size: size, color: color);
      case 'screenshot':
        return Icon(Icons.cut, size: size * 0.5, color: color);
      default:
        return Image.asset(
          item.iconPath!,
          width: size,
          height: size,
          color: color,
        );
    }
  }

  Future<void> _onClickItem(BuildContext context, String key) async {
    var conversationController =
        Provider.of<ConversationController>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case "album":
        {
          if (isDesktopShell) {
            FilePicker.platform.pickFiles(type: FileType.image).then((value) {
              if (value != null && value.files.isNotEmpty) {
                conversationController.onPickImage(
                    conversation, value.files.first.path!);
              }
            });
          } else if (WfcPlatform.isAndroid || WfcPlatform.isIOS) {
            // 微信式应用内相册多选
            _pickImagesWithAssetPicker(context, conversationController);
          } else {
            // ohos:photo_manager 无实现,走系统多选选择器
            var picker = ImagePicker();
            picker.pickMultiImage(limit: _maxImagePickCount).then((files) {
              if (files.isEmpty) {
                return;
              }
              // 系统选择器不一定支持 limit,超出时裁剪并提示
              final selected = files.length > _maxImagePickCount
                  ? files.sublist(0, _maxImagePickCount)
                  : files;
              if (files.length > _maxImagePickCount) {
                showToast(msg: l10n.maxImageSelectLimit(_maxImagePickCount));
              }
              for (final file in selected) {
                conversationController.onPickImage(conversation, file.path);
              }
            });
          }
        }
        break;
      case "camera":
        if (!(WfcPlatform.isAndroid || WfcPlatform.isIOS)) {
          showToast(msg: l10n.notSupportedOnCurrentPlatform);
          return;
        }
        CameraPicker.pickFromCamera(context,
                pickerConfig: const CameraPickerConfig(
                    enableRecording: true,
                    resolutionPreset: ResolutionPreset.high))
            .then((entity) {
          if (entity != null) {
            if (entity.type == AssetType.image) {
              entity.file.then((file) {
                if (file != null) {
                  conversationController.cameraCaptureImage(
                      conversation, file.path);
                }
              });
            } else if (entity.type == AssetType.video) {
              entity.file.then((file) async {
                if (file != null) {
                  Uint8List? thumbData = await entity.thumbnailDataWithSize(
                      const ThumbnailSize.square(120),
                      quality: 30);
                  img.Image? thumb;
                  if (thumbData != null) {
                    thumb = img.decodeJpg((await entity.thumbnailData)!);
                  }
                  // AssetEntity.duration 视频是「秒」,而消息协议里 duration 是「毫秒」,
                  // 直接透传会让对端把 15 秒的视频显示成 00:00
                  conversationController.cameraCaptureVideo(
                      conversation, file.path, thumb, entity.duration * 1000);
                }
              });
            }
          }
        });
        break;
      case "call":
        conversationController.onPressCallBtn(context, conversation);
        break;
      case "location":
        showToast(msg: l10n.notSupported);
        break;
      case "file":
        FilePicker.platform.pickFiles().then((value) {
          if (value != null && value.files.isNotEmpty) {
            String path = value.files.first.path!;
            String name = value.files.first.name;
            int size = value.files.first.size;
            // _pickerFileCallback(path, name, size);
            conversationController.onPickFile(conversation, path, name, size);
          }
        });
        break;
      case "card":
        // _pressCardBtnCallback();
        conversationController.onPressCardBtn(context, conversation);
        break;
      case "screenshot":
        {
          final available = await ScreenshotService.isAvailable;
          if (!available) {
            showToast(msg: l10n.screenshotToolNotAvailable);
            return;
          }
          final result = await ScreenshotService.captureToFile(l10n);
          if (result.success) {
            conversationController.onPickImage(conversation, result.path!);
          } else if (result.error != null) {
            showToast(msg: result.error!);
          }
        }
        break;
      case "collection":
        CreateCollectionScreen.show(context, conversation);
        break;
      case "poll":
        PollHomeScreen.show(context, conversation.target);
        break;
    }
  }

  /// 微信式应用内相册多选(Android/iOS),最多 [_maxImagePickCount] 张
  Future<void> _pickImagesWithAssetPicker(BuildContext context,
      ConversationController conversationController) async {
    final List<File> files = await pickImagesWithWfAssetPicker(context,
        maxAssets: _maxImagePickCount);
    for (final File file in files) {
      conversationController.onPickImage(conversation, file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    double boardHeight = height ?? 250;
    final pluginItems = _getPluginItems();
    final double extent =
        LayoutScale.watchScale(context, 120, cap: LayoutScale.rowCap);
    return SizedBox(
        height: boardHeight,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: extent,
          ),
          itemCount: pluginItems.length,
          itemBuilder: (context, index) {
            return _pluginItemWidget(context, pluginItems[index]);
          },
        ));
    // return Column(
    //   children: [
    //     Row(
    //       children: _getLineItem(context, _line1),
    //     ),
    //     Row(
    //       children: _getLineItem(context, _line2),
    //     ),
    //   ],
    // );
  }
}
