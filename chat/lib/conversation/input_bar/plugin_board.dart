import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:provider/provider.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/collection/create_collection_screen.dart';
import 'package:chat/collection/collection_icon.dart';
import 'package:chat/poll/poll_home_screen.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/utils/screenshot_service.dart';

class _PluginItem {
  String iconPath;
  String key;

  _PluginItem(this.iconPath, this.key);
}

class PluginBoard extends StatelessWidget {
  PluginBoard(this.conversation, {super.key, this.height});

  final Conversation conversation;
  final double? height;

  List<_PluginItem> _getPluginItems() {
    final items = [
      _PluginItem('assets/images/input/album.png',  "album"),
      if (isDesktopShell) _PluginItem('', "screenshot"),
      if (!isDesktopShell) _PluginItem('assets/images/input/camera.png', "camera"),
      if (!isDesktopShell) _PluginItem('assets/images/input/call.png', "call"),
      if (!isDesktopShell) _PluginItem('assets/images/input/location.png', "location"),
      _PluginItem('assets/images/input/file.png', "file"),
      _PluginItem('assets/images/input/card.png', "card"),
    ];

    // 群接龙仅在群组中且配置了服务地址时显示
    if (conversation.conversationType == ConversationType.Group &&
        Config.collectionServerAddress != null &&
        Config.collectionServerAddress!.isNotEmpty) {
      items.add(_PluginItem('assets/images/input/collection.png', "collection"));
    }

    // 群投票仅在群组中且配置了服务地址时显示
    if (conversation.conversationType == ConversationType.Group &&
        Config.pollServerAddress != null &&
        Config.pollServerAddress!.isNotEmpty) {
      items.add(_PluginItem('assets/images/input/poll.png', "poll"));
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
        return l10n.voiceCall;
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
    final double itemWidth = LayoutScale.watchScale(context, 64, cap: LayoutScale.iconCap);
    return GestureDetector(
      onTap: () => _onClickItem(context, item.key),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIcon(item, itemWidth),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              _getPluginTitle(context, item.key),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(_PluginItem item, double size) {
    // 接龙图标使用自定义 Widget
    if (item.key == 'collection') {
      return CollectionIconWidget(size: size);
    }
    // 投票图标使用自定义 Widget
    if (item.key == 'poll') {
      return _buildPollIcon(size);
    }
    // 截屏按钮使用 Material 图标
    if (item.key == 'screenshot') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Icon(
          Icons.cut,
          size: size * 0.5,
          color: const Color(0xFF585858),
        ),
      );
    }
    // 其他图标使用图片资源
    return Image.asset(
      item.iconPath,
      width: size,
      height: size,
    );
  }

  Widget _buildPollIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Icon(
          Icons.poll,
          size: size * 0.5,
          color: const Color(0xFF585858),
        ),
      ),
    );
  }

  Future<void> _onClickItem(BuildContext context, String key) async {
    var conversationController = Provider.of<ConversationController>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case "album":
        {
          if (isDesktopShell) {
            FilePicker.platform.pickFiles(type: FileType.image).then((value) {
              if (value != null && value.files.isNotEmpty) {
                conversationController.onPickImage(conversation, value.files.first.path!);
              }
            });
          } else {
            var picker = ImagePicker();
            picker.pickImage(source: ImageSource.gallery).then((value) {
              if (value != null) {
                conversationController.onPickImage(conversation, value.path);
              }
            });
          }
        }
        break;
      case "camera":
        if(!['android', 'ios'].contains(Platform.operatingSystem) ){
          showToast(msg: l10n.notSupportedOnCurrentPlatform);
          return;
        }
        CameraPicker.pickFromCamera(context, pickerConfig: const CameraPickerConfig(enableRecording: true, resolutionPreset: ResolutionPreset.high)).then((entity) {
          if (entity != null) {
            if (entity.type == AssetType.image) {
              entity.file.then((file) {
                if (file != null) {
                  conversationController.cameraCaptureImage(conversation, file.path);
                }
              });
            } else if (entity.type == AssetType.video) {
              entity.file.then((file) async {
                if (file != null) {
                  Uint8List? thumbData = await entity.thumbnailDataWithSize(const ThumbnailSize.square(120), quality: 30);
                  img.Image? thumb;
                  if (thumbData != null) {
                    thumb = img.decodeJpg((await entity.thumbnailData)!);
                  }
                  conversationController.cameraCaptureVideo(conversation, file.path, thumb, entity.duration);
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
          final result = await ScreenshotService.captureToFile();
          if (result.success) {
            conversationController.onPickImage(conversation, result.path!);
          } else if (result.error != null) {
            showToast(msg: result.error!);
          }
        }
        break;
      case "collection":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateCollectionScreen(conversation: conversation),
          ),
        );
        break;
      case "poll":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PollHomeScreen(groupId: conversation.target),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    double boardHeight = height ?? 250;
    final pluginItems = _getPluginItems();
    final double extent = LayoutScale.watchScale(context, 120, cap: LayoutScale.rowCap);
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
