import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';

class SettingsTab extends StatefulWidget {
  @override
  _SettingsTabState createState() => _SettingsTabState();

  void selectMedia() async {
    var picker = ImagePicker();
    var image = await picker.pickImage(source: ImageSource.gallery);
    debugPrint(image?.path);
    var datas = await image?.readAsBytes();
    if (datas == null) {
      Fluttertoast.showToast(msg: "读取媒体数据为空");
      return;
    }
    Imclient.uploadMedia(
      image!.path,
      datas,
      MediaType.Media_Type_PORTRAIT.index,
      (strValue) {
        debugPrint("upload complete:$strValue");
      },
      (uploaded, total) {
        debugPrint("total:$total uploaded:$uploaded");
      },
      (errorCode) {
        debugPrint("errorCode:$errorCode");
      },
    );
  }
}

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Imclient.disconnect();
              },
              child: Text('退出'),
              // color: Colors.red,
            ),
            ElevatedButton(
              onPressed: widget.selectMedia,
              child: const Text('上传媒体图片'),
              // color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
