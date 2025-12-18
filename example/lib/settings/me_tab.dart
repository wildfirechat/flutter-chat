import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/settings/general_settings.dart';
import 'package:wfc_example/settings/message_notification_settings.dart';

import 'package:wfc_example/viewmodel/user_view_model.dart';
import 'package:wfc_example/widget/option_item.dart';
import 'package:wfc_example/widget/portrait.dart';
import 'package:wfc_example/widget/section_divider.dart';

import '../config.dart';
import '../user_info_widget.dart';

class MeTab extends StatelessWidget {
  const MeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SelfProfile(),
              const SectionDivider(),
              OptionItem(
                '消息通知',
                leftImage: Image.asset('assets/images/setting_message_notification.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MessageNotificationSettings()),
                  );
                },
              ),
              const SectionDivider(),
              OptionItem(
                '收藏',
                leftImage: Image.asset('assets/images/setting_favorite.png', width: 20.0, height: 20.0),
                onTap: () {
                  Fluttertoast.showToast(msg: "方法没有实现");
                },
              ),
              const SectionDivider(),
              OptionItem(
                '文件',
                leftImage: Image.asset('assets/images/setting_file.png', width: 20.0, height: 20.0),
                onTap: () {
                  Fluttertoast.showToast(msg: "方法没有实现");
                },
              ),
              const SectionDivider(),
              OptionItem(
                '账户安全',
                leftImage: Image.asset('assets/images/setting_safety.png', width: 20.0, height: 20.0),
                onTap: () {
                  Fluttertoast.showToast(msg: "方法没有实现");
                },
              ),
              const SectionDivider(),
              OptionItem(
                '设置',
                leftImage: Image.asset('assets/images/setting_general.png', width: 20.0, height: 20.0),
                showBottomDivider: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GeneralSettings()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelfProfile extends StatelessWidget {
  const SelfProfile({Key? key}) : super(key: key);

  void _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      Imclient.uploadMediaFile(image.path, MediaType.Media_Type_PORTRAIT, (url) {
        Imclient.modifyMyInfo({ModifyMyInfoType.Modify_Portrait: url}, () {
          Fluttertoast.showToast(msg: "修改头像成功");
        }, (code) {
          Fluttertoast.showToast(msg: "修改头像失败: $code");
        });
      }, (uploaded, total) {
        // progress
      }, (code) {
        Fluttertoast.showToast(msg: "上传头像失败: $code");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UserViewModel, UserInfo?>(
      selector: (context, viewModel) => viewModel.getUserInfo(Imclient.currentUserId),
      builder: (context, userInfo, child) {
        if (userInfo == null) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            child: const Text("加载中。。。"),
          );
        } else {
          return Container(
              height: 80,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  Portrait(
                    userInfo.portrait ?? Config.defaultUserPortrait,
                    Config.defaultUserPortrait,
                    width: 60,
                    height: 60,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('拍摄'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('从相册选择'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.gallery);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  GestureDetector(
                    child: Container(
                      margin: const EdgeInsets.only(left: 10, top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo.displayName!,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 18),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                          ),
                          Container(
                            constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width / View.of(context).devicePixelRatio - 100),
                            child: Text(
                              '野火号:${userInfo.name}',
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3b3b3b),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
                      );
                    },
                  )
                ],
              ));
        }
      },
    );
  }
}
