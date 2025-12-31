import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/settings/general_settings.dart';
import 'package:chat/settings/message_notification_settings.dart';
import 'package:chat/settings/favorite_list_screen.dart';
import 'package:chat/settings/file_records_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/widget/section_divider.dart';

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
                AppLocalizations.of(context)!.messageNotification,
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
                AppLocalizations.of(context)!.favorites,
                leftImage: Image.asset('assets/images/setting_favorite.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FavoriteListScreen()),
                  );
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.files,
                leftImage: Image.asset('assets/images/setting_file.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FileRecordsScreen()),
                  );
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.accountSafety,
                leftImage: Image.asset('assets/images/setting_safety.png', width: 20.0, height: 20.0),
                onTap: () {
                  Fluttertoast.showToast(msg: "方法没有实现");
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.settings,
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

  void _pickImage(ImageSource source, BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      Imclient.uploadMediaFile(image.path, MediaType.Media_Type_PORTRAIT, (url) {
        Imclient.modifyMyInfo({ModifyMyInfoType.Modify_Portrait: url}, () {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.modifyPortraitSuccess);
        }, (code) {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.modifyPortraitFail(code.toString()));
        });
      }, (uploaded, total) {
        // progress
      }, (code) {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.uploadPortraitFail(code.toString()));
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
            child: Text(AppLocalizations.of(context)!.loading),
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
                                  title: Text(AppLocalizations.of(context)!.takePhoto),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.camera, context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: Text(AppLocalizations.of(context)!.selectFromAlbum),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.gallery, context);
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
                              AppLocalizations.of(context)!.wildfireId(userInfo.name!),
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
