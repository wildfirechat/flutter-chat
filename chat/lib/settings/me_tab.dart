import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat/conversation/input_bar/wf_asset_picker_delegate.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/settings/general_settings.dart';
import 'package:chat/settings/message_notification_settings.dart';
import 'package:chat/pc/pc_favorite_list_widget.dart';
import 'package:chat/settings/file_records_screen.dart';
import 'package:chat/backup/backup_and_restore_screen.dart';
import 'package:chat/settings/account_safety_screen.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';

import '../config.dart';
import '../pc/pc_platform.dart';
import '../user_info_widget.dart';
import 'package:chat/theme/app_typography.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: context.colors.surface,
              child: const SelfProfile(),
            ),
            const SizedBox(height: 18),
            Container(
              color: context.colors.surface,
              child: OptionItem(
                AppLocalizations.of(context)!.messageNotification,
                leftImage: Image.asset(
                    'assets/images/setting_message_notification.png',
                    width: 20.0,
                    height: 20.0),
                showBottomDivider: false,
                onTap: () {
                  openPage(context, const MessageNotificationSettings());
                },
              ),
            ),
            const SizedBox(height: 18),
            if (!isDesktopShell)
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    OptionItem(
                      AppLocalizations.of(context)!.favorites,
                      leftImage: Image.asset(
                          'assets/images/setting_favorite.png',
                          width: 20.0,
                          height: 20.0),
                      onTap: () {
                        openPage(
                            context,
                            const FavoriteListWidget(
                                category: FavoriteCategory.all,
                                isEmbedded: false));
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.files,
                      leftImage: Image.asset('assets/images/setting_file.png',
                          width: 20.0, height: 20.0),
                      showBottomDivider: false,
                      onTap: () {
                        openPage(context, const FileRecordsScreen());
                      },
                    ),
                  ],
                ),
              ),
            if (!isDesktopShell) const SizedBox(height: 18),
            Container(
              color: context.colors.surface,
              child: OptionItem(
                AppLocalizations.of(context)!.backup_and_restore,
                leftImage:
                    const Icon(Icons.backup, color: Colors.blue, size: 20),
                showBottomDivider: false,
                onTap: () {
                  openPage(context, const BackupAndRestoreScreen());
                },
              ),
            ),
            const SizedBox(height: 18),
            Container(
              color: context.colors.surface,
              child: Column(
                children: [
                  OptionItem(
                    AppLocalizations.of(context)!.accountSafety,
                    leftImage: Image.asset('assets/images/setting_safety.png',
                        width: 20.0, height: 20.0),
                    onTap: () {
                      openPage(context, const AccountSafetyScreen());
                    },
                  ),
                  OptionItem(
                    AppLocalizations.of(context)!.settings,
                    leftImage: Image.asset('assets/images/setting_general.png',
                        width: 20.0, height: 20.0),
                    showBottomDivider: false,
                    onTap: () {
                      openPage(context, const GeneralSettings());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelfProfile extends StatelessWidget {
  const SelfProfile({super.key});

  void _pickImage(ImageSource source, BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null && context.mounted) {
      _uploadPortrait(image.path, context);
    }
  }

  /// 相册选头像:Android/iOS 走微信式应用内相册(首格带"拍摄"入口),
  /// 桌面/ohos 无 photo_manager 实现,仍走系统选择器
  void _pickPortraitFromAlbum(BuildContext context) async {
    if (WfcPlatform.isAndroid || WfcPlatform.isIOS) {
      final files = await pickImagesWithWfAssetPicker(context,
          maxAssets: 1, showTakePhotoEntry: true);
      if (files.isNotEmpty && context.mounted) {
        _uploadPortrait(files.first.path, context);
      }
    } else {
      _pickImage(ImageSource.gallery, context);
    }
  }

  void _uploadPortrait(String path, BuildContext context) {
    Imclient.uploadMediaFile(path, MediaType.Media_Type_PORTRAIT, (url) {
      Imclient.modifyMyInfo({ModifyMyInfoType.Modify_Portrait: url}, () {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.modifyPortraitSuccess);
      }, (code) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!
                .modifyPortraitFail(code.toString()));
      });
    }, (uploaded, total) {
      // progress
    }, (code) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!
              .uploadPortraitFail(code.toString()));
    });
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FontSizeViewModel>(
        context); // Trigger rebuild when font size changes
    return Selector<UserViewModel, UserInfo?>(
      selector: (context, viewModel) =>
          viewModel.getUserInfo(Imclient.currentUserId),
      builder: (context, userInfo, child) {
        if (userInfo == null) {
          return Container(
            constraints: BoxConstraints(
                minHeight: LayoutScale.watchScale(context, 70.0,
                    cap: LayoutScale.rowCap)),
            alignment: Alignment.center,
            child: Text(AppLocalizations.of(context)!.loading),
          );
        } else {
          return Container(
              constraints: BoxConstraints(
                  minHeight: LayoutScale.watchScale(context, 70.0,
                      cap: LayoutScale.rowCap)),
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Portrait(
                    userInfo.portrait ?? Config.defaultUserPortrait,
                    Config.defaultUserPortrait,
                    width: 60,
                    height: 60,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        // 弹层关闭后上传回调还会用到 context,这里必须把外层
                        // context 传下去,不能用已 pop 的 sheetContext
                        builder: (BuildContext sheetContext) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: Text(AppLocalizations.of(sheetContext)!
                                      .takePhoto),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _pickImage(ImageSource.camera, context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: Text(AppLocalizations.of(sheetContext)!
                                      .selectFromAlbum),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _pickPortraitFromAlbum(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      child: Container(
                        margin: const EdgeInsets.only(
                            left: 10, top: 0, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userInfo.displayName ?? userInfo.name,
                              textAlign: TextAlign.left,
                              style: AppText.lg,
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                            ),
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth: View.of(context)
                                              .physicalSize
                                              .width /
                                          View.of(context).devicePixelRatio -
                                      100),
                              child: Text(
                                AppLocalizations.of(context)!
                                    .wildfireId(userInfo.name),
                                textAlign: TextAlign.left,
                                style: AppText.xs.copyWith(color: context.colors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          ],
                        ),
                      ),
                      onTap: () {
                        openPage(context, UserInfoWidget(userInfo.userId));
                      },
                    ),
                  )
                ],
              ));
        }
      },
    );
  }
}
