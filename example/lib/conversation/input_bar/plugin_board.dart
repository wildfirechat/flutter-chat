import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:wfc_example/conversation/conversation_controller.dart';

class _PluginItem {
  String iconPath;
  String title;
  String key;

  _PluginItem(this.iconPath, this.title, this.key);
}

class PluginBoard extends StatelessWidget {
  PluginBoard(this.conversation, {super.key});

  final Conversation conversation;

  final List<_PluginItem> _line1 = [
    _PluginItem('assets/images/input/album.png', "相册", "album"),
    _PluginItem('assets/images/input/camera.png', "拍摄", "camera"),
    _PluginItem('assets/images/input/call.png', "通话", "call"),
    _PluginItem('assets/images/input/location.png', "位置", "location"),
    _PluginItem('assets/images/input/file.png', "文件", "file"),
    _PluginItem('assets/images/input/card.png', "名片", "card"),
  ];
  final List<_PluginItem> _line2 = [
    _PluginItem('assets/images/input/file.png', "文件", "file"),
    _PluginItem('assets/images/input/card.png', "名片", "card"),
  ];

  List<Widget> _getLineItem(BuildContext context, List<_PluginItem> line) {
    double width = View.of(context).physicalSize.width / View.of(context).devicePixelRatio;
    double itemWidth = 54;
    double padding = (width - 4 * itemWidth) / 4 / 2;
    List<Widget> items = [];
    for (var value in line) {
      items.add(Padding(padding: EdgeInsets.only(left: padding)));
      items.add(GestureDetector(
        onTap: () => _onClickItem(context, value.key),
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(top: padding)),
            Image.asset(
              value.iconPath,
              width: itemWidth,
              height: itemWidth,
            ),
            const Padding(padding: EdgeInsets.only(top: 10)),
            Text(value.title),
          ],
        ),
      ));
      items.add(Padding(padding: EdgeInsets.only(left: padding)));
    }

    return items;
  }

  Widget _pluginItemWidget(BuildContext context, _PluginItem item) {
    double width = View.of(context).physicalSize.width / View.of(context).devicePixelRatio;
    double itemWidth = 54;
    double padding = (width - 4 * itemWidth) / 4 / 2;
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: padding)),
        GestureDetector(
          onTap: () => _onClickItem(context, item.key),
          child: Column(
            children: [
              Padding(padding: EdgeInsets.only(top: padding)),
              Image.asset(
                item.iconPath,
                width: itemWidth,
                height: itemWidth,
              ),
              const Padding(padding: EdgeInsets.only(top: 10)),
              Text(item.title),
            ],
          ),
        ),
        Padding(padding: EdgeInsets.only(left: padding))
      ],
    );
  }

  void _onClickItem(BuildContext context, String key) {
    var conversationController = Provider.of<ConversationController>(context, listen: false);
    switch (key) {
      case "album":
        {
          var picker = ImagePicker();
          picker.pickImage(source: ImageSource.gallery).then((value) {
            if (value != null) {
              conversationController.onPickImage(conversation, value.path);
            }
          });
        }
        break;
      case "camera":
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
        // _pressCallBtnCallback();
        conversationController.onPressCallBtn(context, conversation);
        break;
      case "location":
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 250,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
          itemCount: _line1.length,
          itemBuilder: (context, index) {
            return _pluginItemWidget(context, _line1[index]);
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
