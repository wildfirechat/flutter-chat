import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/settings/general_settings.dart';
import 'package:chat/settings/message_notification_settings.dart';
import 'package:chat/settings/favorite_list_screen.dart';
import 'package:chat/settings/file_records_screen.dart';
import 'package:chat/backup/backup_and_restore_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/widget/section_divider.dart';

import '../config.dart';
import '../user_info_widget.dart';

class MeTab extends StatelessWidget {
  /// 桌面端用于在右栏打开子页面;手机端可忽略。
  final void Function(Widget page)? onOpenPage;
  /// 桌面端登出回调，由 PCHome 用根 Navigator 切到登录页。
  final VoidCallback? onLogout;

  const MeTab({super.key, this.onOpenPage, this.onLogout});

  static void _openPage(BuildContext context, Widget page, void Function(Widget page)? onOpenPage) {
    if (isDesktopShell && onOpenPage != null) {
      onOpenPage(page);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  void _logout() {
    if (isDesktopShell && onLogout != null) {
      onLogout!();
    }
    // 手机端 GeneralSettings 内部自行处理登出。
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SelfProfile(onOpenPage: onOpenPage),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.messageNotification,
                leftImage: Image.asset('assets/images/setting_message_notification.png', width: 20.0, height: 20.0),
                onTap: () {
                  _openPage(context, MessageNotificationSettings(), onOpenPage);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.favorites,
                leftImage: Image.asset('assets/images/setting_favorite.png', width: 20.0, height: 20.0),
                onTap: () {
                  _openPage(context, const FavoriteListScreen(), onOpenPage);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.files,
                leftImage: Image.asset('assets/images/setting_file.png', width: 20.0, height: 20.0),
                onTap: () {
                  _openPage(context, const FileRecordsScreen(), onOpenPage);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.backup_and_restore,
                leftImage: const Icon(Icons.backup, color: Colors.blue, size: 20),
                onTap: () {
                  _openPage(context, const BackupAndRestoreScreen(), onOpenPage);
                },
              ),
              const SectionDivider(),

              OptionItem(
                AppLocalizations.of(context)!.accountSafety,
                leftImage: Image.asset('assets/images/setting_safety.png', width: 20.0, height: 20.0),
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.settings,
                leftImage: Image.asset('assets/images/setting_general.png', width: 20.0, height: 20.0),
                showBottomDivider: true,
                onTap: () {
                  _openPage(context, GeneralSettings(onLogout: _logout), onOpenPage);
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
  final void Function(Widget page)? onOpenPage;

  const SelfProfile({super.key, this.onOpenPage});

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
                            userInfo.displayName ?? userInfo.name,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 18),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                          ),
                          Container(
                            constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width / View.of(context).devicePixelRatio - 100),
                            child: Text(
                              AppLocalizations.of(context)!.wildfireId(userInfo.name),
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
                      MeTab._openPage(context, UserInfoWidget(userInfo.userId), onOpenPage);
                    },
                  )
                ],
              ));
        }
      },
    );
  }
}
