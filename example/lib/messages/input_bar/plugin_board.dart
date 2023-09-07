import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/message/image_message_content.dart';

class _PluginItem {
  String iconPath;
  String title;
  String key;

  _PluginItem(this.iconPath, this.title, this.key);
}

typedef OnPickerImageCallback = void Function(String imagePath);
typedef OnPickerFileCallback = void Function(String filePath, int size);
typedef OnPressCallBtnCallback = void Function();
typedef OnPressCardBtnCallback = void Function();

class PluginBoard extends StatelessWidget {
  PluginBoard(this._pickerImageCallback, this._pickerFileCallback, this._pressCallBtnCallback, this._pressCardBtnCallback, {Key? key}) : super(key: key);

  final OnPickerImageCallback _pickerImageCallback;
  final OnPickerFileCallback _pickerFileCallback;
  final OnPressCallBtnCallback _pressCallBtnCallback;
  final OnPressCardBtnCallback _pressCardBtnCallback;

  final List<_PluginItem> _line1 = [
    _PluginItem('assets/images/input/album.png', "相册", "album"),
    _PluginItem('assets/images/input/call.png', "通话", "call"),
    _PluginItem('assets/images/input/camera.png', "拍摄", "camera"),
    _PluginItem('assets/images/input/location.png', "位置", "location"),
  ];
  final List<_PluginItem> _line2 = [
    _PluginItem('assets/images/input/file.png', "文件", "file"),
    _PluginItem('assets/images/input/card.png', "名片", "card"),
  ];

  List<Widget> _getLineItem(BuildContext context, List<_PluginItem> line) {
    double width = View.of(context).physicalSize.width/View.of(context).devicePixelRatio;
    double itemWidth = 54;
    double padding = (width - 4*itemWidth)/4/2;
    List<Widget> items = [];
    for (var value in line) {
      items.add(Padding(padding: EdgeInsets.only(left: padding)));
      items.add(GestureDetector(
        onTap: () => _onClickItem(value.key),
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(top: padding)),
            Image.asset(value.iconPath, width: itemWidth, height: itemWidth,),
            const Padding(padding: EdgeInsets.only(top: 10)),
            Text(value.title),
          ],
        ),
      )
      );
      items.add(Padding(padding: EdgeInsets.only(left: padding)));
    }

    return items;
  }

  void _onClickItem(String key) {
    switch(key) {
      case "album":{
        var picker = ImagePicker();
        picker.pickImage(source: ImageSource.gallery).then((value) {
          if(value!= null) {
            _pickerImageCallback(value.path);
          }
        });
      }
        break;
      case "camera":
        break;
      case "call": {
        _pressCallBtnCallback();
      }
        break;
      case "location":
        break;
      case "file": {
        FilePicker.platform.pickFiles().then((value) {
          if(value != null && value.files.isNotEmpty) {
            String path = value.files.first.name;
            int size = value.files.first.size;
            _pickerFileCallback(path, size);
          }
        });
      }
        break;
      case "card":
        _pressCardBtnCallback();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: _getLineItem(context, _line1),
        ),
        Row(
          children: _getLineItem(context, _line2),
        ),
      ],
    );
  }
}