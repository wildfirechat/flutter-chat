import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'野火IM'**
  String get appName;

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'野火IM'**
  String get appTitle;

  /// No description provided for @tabChat.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get tabChat;

  /// No description provided for @tabContact.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get tabContact;

  /// No description provided for @tabWork.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get tabWork;

  /// No description provided for @tabDiscovery.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get tabDiscovery;

  /// No description provided for @tabMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabMe;

  /// No description provided for @startChat.
  ///
  /// In zh, this message translates to:
  /// **'发起聊天'**
  String get startChat;

  /// No description provided for @addFriend.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get addFriend;

  /// No description provided for @scanQrCode.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get scanQrCode;

  /// No description provided for @scanResult.
  ///
  /// In zh, this message translates to:
  /// **'扫描结果: {result}'**
  String scanResult(Object result);

  /// No description provided for @scanFail.
  ///
  /// In zh, this message translates to:
  /// **'扫描失败: {error}'**
  String scanFail(Object error);

  /// No description provided for @invalidQrCode.
  ///
  /// In zh, this message translates to:
  /// **'无效的二维码: {qrcode}'**
  String invalidQrCode(Object qrcode);

  /// No description provided for @pcLoginNotSupport.
  ///
  /// In zh, this message translates to:
  /// **'PC登录暂未支持'**
  String get pcLoginNotSupport;

  /// No description provided for @pcLoginQrHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用手机野火IM扫码登录'**
  String get pcLoginQrHint;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @channelNotSupport.
  ///
  /// In zh, this message translates to:
  /// **'频道功能暂未支持'**
  String get channelNotSupport;

  /// No description provided for @conferenceNotSupport.
  ///
  /// In zh, this message translates to:
  /// **'会议功能暂未支持'**
  String get conferenceNotSupport;

  /// No description provided for @groupInfo.
  ///
  /// In zh, this message translates to:
  /// **'群组信息'**
  String get groupInfo;

  /// No description provided for @joinGroup.
  ///
  /// In zh, this message translates to:
  /// **'加入群聊'**
  String get joinGroup;

  /// No description provided for @enterGroup.
  ///
  /// In zh, this message translates to:
  /// **'进入群聊'**
  String get enterGroup;

  /// No description provided for @joinFail.
  ///
  /// In zh, this message translates to:
  /// **'加入失败: {error}'**
  String joinFail(Object error);

  /// No description provided for @groupName.
  ///
  /// In zh, this message translates to:
  /// **'群聊名称'**
  String get groupName;

  /// No description provided for @groupQrCode.
  ///
  /// In zh, this message translates to:
  /// **'群二维码'**
  String get groupQrCode;

  /// No description provided for @groupNotice.
  ///
  /// In zh, this message translates to:
  /// **'群公告'**
  String get groupNotice;

  /// No description provided for @clickToCheck.
  ///
  /// In zh, this message translates to:
  /// **'点击查看'**
  String get clickToCheck;

  /// No description provided for @groupRemark.
  ///
  /// In zh, this message translates to:
  /// **'群备注'**
  String get groupRemark;

  /// No description provided for @groupManage.
  ///
  /// In zh, this message translates to:
  /// **'群管理'**
  String get groupManage;

  /// No description provided for @searchChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'查找聊天内容'**
  String get searchChatHistory;

  /// No description provided for @chatFiles.
  ///
  /// In zh, this message translates to:
  /// **'会话文件'**
  String get chatFiles;

  /// No description provided for @muteNotification.
  ///
  /// In zh, this message translates to:
  /// **'消息免打扰'**
  String get muteNotification;

  /// No description provided for @stickTop.
  ///
  /// In zh, this message translates to:
  /// **'置顶聊天'**
  String get stickTop;

  /// No description provided for @saveToContact.
  ///
  /// In zh, this message translates to:
  /// **'保存到通讯录'**
  String get saveToContact;

  /// No description provided for @myAliasInGroup.
  ///
  /// In zh, this message translates to:
  /// **'我在本群的昵称'**
  String get myAliasInGroup;

  /// No description provided for @showMemberName.
  ///
  /// In zh, this message translates to:
  /// **'显示群成员昵称'**
  String get showMemberName;

  /// No description provided for @clearChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录'**
  String get clearChatHistory;

  /// No description provided for @transferGroup.
  ///
  /// In zh, this message translates to:
  /// **'转移群组'**
  String get transferGroup;

  /// No description provided for @dismissGroup.
  ///
  /// In zh, this message translates to:
  /// **'解散群组'**
  String get dismissGroup;

  /// No description provided for @quitGroup.
  ///
  /// In zh, this message translates to:
  /// **'退出群组'**
  String get quitGroup;

  /// No description provided for @clearLocalHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空本地消息'**
  String get clearLocalHistory;

  /// No description provided for @clearRemoteHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空远程消息'**
  String get clearRemoteHistory;

  /// No description provided for @clearLocalHistorySuccess.
  ///
  /// In zh, this message translates to:
  /// **'清理本地消息成功'**
  String get clearLocalHistorySuccess;

  /// No description provided for @clearRemoteHistorySuccess.
  ///
  /// In zh, this message translates to:
  /// **'清理远程消息成功'**
  String get clearRemoteHistorySuccess;

  /// No description provided for @clearRemoteHistoryFail.
  ///
  /// In zh, this message translates to:
  /// **'清理远程消息失败: {error}'**
  String clearRemoteHistoryFail(Object error);

  /// No description provided for @kickMember.
  ///
  /// In zh, this message translates to:
  /// **'移除群成员'**
  String get kickMember;

  /// No description provided for @addMember.
  ///
  /// In zh, this message translates to:
  /// **'添加群成员'**
  String get addMember;

  /// No description provided for @pickContact.
  ///
  /// In zh, this message translates to:
  /// **'选择联系人'**
  String get pickContact;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @modifyGroupName.
  ///
  /// In zh, this message translates to:
  /// **'修改群名称'**
  String get modifyGroupName;

  /// No description provided for @modifyFail.
  ///
  /// In zh, this message translates to:
  /// **'修改失败: {error}'**
  String modifyFail(Object error);

  /// No description provided for @onlyOwnerManagerCanModify.
  ///
  /// In zh, this message translates to:
  /// **'只有群主和管理员可以修改群名称'**
  String get onlyOwnerManagerCanModify;

  /// No description provided for @modifyGroupRemark.
  ///
  /// In zh, this message translates to:
  /// **'修改群备注'**
  String get modifyGroupRemark;

  /// No description provided for @modifyGroupAlias.
  ///
  /// In zh, this message translates to:
  /// **'修改群昵称'**
  String get modifyGroupAlias;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @loginConfirm.
  ///
  /// In zh, this message translates to:
  /// **'登录确认'**
  String get loginConfirm;

  /// No description provided for @pcLoginConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'Windows/Mac 电脑登录确认'**
  String get pcLoginConfirmDesc;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @cancelLogin.
  ///
  /// In zh, this message translates to:
  /// **'取消登录'**
  String get cancelLogin;

  /// No description provided for @loginWithCodeOrPassword.
  ///
  /// In zh, this message translates to:
  /// **'验证码/密码登录'**
  String get loginWithCodeOrPassword;

  /// No description provided for @loginCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证码登录'**
  String get loginCodeTitle;

  /// No description provided for @scanned.
  ///
  /// In zh, this message translates to:
  /// **'已扫码，请在手机上确认登录'**
  String get scanned;

  /// No description provided for @scannedUser.
  ///
  /// In zh, this message translates to:
  /// **'扫描用户：{user}'**
  String scannedUser(Object user);

  /// No description provided for @loggingIn.
  ///
  /// In zh, this message translates to:
  /// **'登录中...'**
  String get loggingIn;

  /// No description provided for @scanAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新扫码'**
  String get scanAgain;

  /// No description provided for @pcStatusError.
  ///
  /// In zh, this message translates to:
  /// **'PC端状态异常: {status}'**
  String pcStatusError(Object status);

  /// No description provided for @loginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get loginSuccess;

  /// No description provided for @loginFail.
  ///
  /// In zh, this message translates to:
  /// **'登录失败: {error}'**
  String loginFail(Object error);

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @userInfo.
  ///
  /// In zh, this message translates to:
  /// **'用户详情'**
  String get userInfo;

  /// No description provided for @sendMsg.
  ///
  /// In zh, this message translates to:
  /// **'发送消息'**
  String get sendMsg;

  /// No description provided for @videoCall.
  ///
  /// In zh, this message translates to:
  /// **'视频聊天'**
  String get videoCall;

  /// No description provided for @modifyAlias.
  ///
  /// In zh, this message translates to:
  /// **'修改昵称'**
  String get modifyAlias;

  /// No description provided for @setAlias.
  ///
  /// In zh, this message translates to:
  /// **'设置备注'**
  String get setAlias;

  /// No description provided for @moreInfo.
  ///
  /// In zh, this message translates to:
  /// **'更多信息'**
  String get moreInfo;

  /// No description provided for @methodNotImpl.
  ///
  /// In zh, this message translates to:
  /// **'方法没有实现'**
  String get methodNotImpl;

  /// No description provided for @inputAlias.
  ///
  /// In zh, this message translates to:
  /// **'请输入备注名'**
  String get inputAlias;

  /// No description provided for @inputNickname.
  ///
  /// In zh, this message translates to:
  /// **'请输入昵称'**
  String get inputNickname;

  /// No description provided for @modifySuccess.
  ///
  /// In zh, this message translates to:
  /// **'修改成功'**
  String get modifySuccess;

  /// No description provided for @setSuccess.
  ///
  /// In zh, this message translates to:
  /// **'设置成功'**
  String get setSuccess;

  /// No description provided for @setFail.
  ///
  /// In zh, this message translates to:
  /// **'设置失败: {error}'**
  String setFail(Object error);

  /// No description provided for @loginPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginPageTitle;

  /// No description provided for @loginWithPhoneNumber.
  ///
  /// In zh, this message translates to:
  /// **'手机号登录'**
  String get loginWithPhoneNumber;

  /// No description provided for @phoneNumberHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入电话号码'**
  String get phoneNumberHint;

  /// No description provided for @superCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入Super code'**
  String get superCodeHint;

  /// No description provided for @sendCodeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'验证码发送成功，请在5分钟内进行验证!'**
  String get sendCodeSuccess;

  /// No description provided for @sendCodeFail.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码失败!'**
  String get sendCodeFail;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @newFriend.
  ///
  /// In zh, this message translates to:
  /// **'新好友'**
  String get newFriend;

  /// No description provided for @favGroup.
  ///
  /// In zh, this message translates to:
  /// **'收藏群组'**
  String get favGroup;

  /// No description provided for @subscribedChannel.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get subscribedChannel;

  /// No description provided for @organization.
  ///
  /// In zh, this message translates to:
  /// **'组织架构'**
  String get organization;

  /// No description provided for @fileTransfer.
  ///
  /// In zh, this message translates to:
  /// **'文件传输助手'**
  String get fileTransfer;

  /// No description provided for @joinChatroomFail.
  ///
  /// In zh, this message translates to:
  /// **'网络错误！加入聊天室失败!'**
  String get joinChatroomFail;

  /// No description provided for @userLeftChatroom.
  ///
  /// In zh, this message translates to:
  /// **'{userName} 离开了聊天室'**
  String userLeftChatroom(Object userName);

  /// No description provided for @selectMessage.
  ///
  /// In zh, this message translates to:
  /// **'请选择消息'**
  String get selectMessage;

  /// No description provided for @deleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除消息'**
  String get deleteMessage;

  /// No description provided for @deleteLocalMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除本地消息'**
  String get deleteLocalMessage;

  /// No description provided for @deleteRemoteMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除远程消息'**
  String get deleteRemoteMessage;

  /// No description provided for @deleteRemoteMessageFail.
  ///
  /// In zh, this message translates to:
  /// **'删除远程消息失败: {error}'**
  String deleteRemoteMessageFail(Object error);

  /// No description provided for @forward.
  ///
  /// In zh, this message translates to:
  /// **'转发'**
  String get forward;

  /// No description provided for @forwardOneByOne.
  ///
  /// In zh, this message translates to:
  /// **'逐条转发'**
  String get forwardOneByOne;

  /// No description provided for @forwardCombined.
  ///
  /// In zh, this message translates to:
  /// **'合并转发'**
  String get forwardCombined;

  /// No description provided for @sendFail.
  ///
  /// In zh, this message translates to:
  /// **'发送失败！'**
  String get sendFail;

  /// No description provided for @sent.
  ///
  /// In zh, this message translates to:
  /// **'已发送'**
  String get sent;

  /// No description provided for @chatHistory.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录'**
  String get chatHistory;

  /// No description provided for @allMembers.
  ///
  /// In zh, this message translates to:
  /// **'所有人'**
  String get allMembers;

  /// No description provided for @messageNotification.
  ///
  /// In zh, this message translates to:
  /// **'消息通知'**
  String get messageNotification;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @files.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get files;

  /// No description provided for @accountSafety.
  ///
  /// In zh, this message translates to:
  /// **'账户安全'**
  String get accountSafety;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @modifyPortraitSuccess.
  ///
  /// In zh, this message translates to:
  /// **'修改头像成功'**
  String get modifyPortraitSuccess;

  /// No description provided for @modifyPortraitFail.
  ///
  /// In zh, this message translates to:
  /// **'修改头像失败: {error}'**
  String modifyPortraitFail(Object error);

  /// No description provided for @uploadPortraitFail.
  ///
  /// In zh, this message translates to:
  /// **'上传头像失败: {error}'**
  String uploadPortraitFail(Object error);

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍摄'**
  String get takePhoto;

  /// No description provided for @selectFromAlbum.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get selectFromAlbum;

  /// No description provided for @wildfireId.
  ///
  /// In zh, this message translates to:
  /// **'野火号: {id}'**
  String wildfireId(Object id);

  /// No description provided for @backup_and_restore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backup_and_restore;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @privacySettings.
  ///
  /// In zh, this message translates to:
  /// **'隐私设置'**
  String get privacySettings;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'反馈'**
  String get feedback;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于野火'**
  String get about;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @complaints.
  ///
  /// In zh, this message translates to:
  /// **'投诉'**
  String get complaints;

  /// No description provided for @diagnostics.
  ///
  /// In zh, this message translates to:
  /// **'诊断'**
  String get diagnostics;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'账号将退出'**
  String get logoutConfirm;

  /// No description provided for @albumPicker.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get albumPicker;

  /// No description provided for @emoji.
  ///
  /// In zh, this message translates to:
  /// **'表情'**
  String get emoji;

  /// No description provided for @image.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get image;

  /// No description provided for @accountLabel.
  ///
  /// In zh, this message translates to:
  /// **'野火号：'**
  String get accountLabel;

  /// No description provided for @tips.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get tips;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @addFriendSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'请在左上角搜索框中输入关键词，即可搜索用户，并添加好友'**
  String get addFriendSearchHint;

  /// No description provided for @friendRequestAccept.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get friendRequestAccept;

  /// No description provided for @friendRequestAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已通过'**
  String get friendRequestAccepted;

  /// No description provided for @friendRequestRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get friendRequestRejected;

  /// No description provided for @enterToSendHint.
  ///
  /// In zh, this message translates to:
  /// **'Enter 发送,Shift + Enter 换行'**
  String get enterToSendHint;

  /// No description provided for @cameraCapture.
  ///
  /// In zh, this message translates to:
  /// **'拍摄'**
  String get cameraCapture;

  /// No description provided for @voiceCall.
  ///
  /// In zh, this message translates to:
  /// **'通话'**
  String get voiceCall;

  /// No description provided for @location.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get location;

  /// No description provided for @filePicker.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get filePicker;

  /// No description provided for @businessCard.
  ///
  /// In zh, this message translates to:
  /// **'名片'**
  String get businessCard;

  /// No description provided for @screenshotTool.
  ///
  /// In zh, this message translates to:
  /// **'截屏'**
  String get screenshotTool;

  /// No description provided for @screenshotToolNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'截屏工具不可用'**
  String get screenshotToolNotAvailable;

  /// No description provided for @notSupportedOnCurrentPlatform.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂不支持'**
  String get notSupportedOnCurrentPlatform;

  /// No description provided for @notSupported.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持'**
  String get notSupported;

  /// No description provided for @singleConversationDetails.
  ///
  /// In zh, this message translates to:
  /// **'单聊会话详情'**
  String get singleConversationDetails;

  /// No description provided for @searchChatContents.
  ///
  /// In zh, this message translates to:
  /// **'查找聊天内容'**
  String get searchChatContents;

  /// No description provided for @clearLocalMessages.
  ///
  /// In zh, this message translates to:
  /// **'清空本地消息'**
  String get clearLocalMessages;

  /// No description provided for @clearRemoteMessages.
  ///
  /// In zh, this message translates to:
  /// **'清空远程消息'**
  String get clearRemoteMessages;

  /// No description provided for @clearLocalMessagesSuccess.
  ///
  /// In zh, this message translates to:
  /// **'清理本地消息成功'**
  String get clearLocalMessagesSuccess;

  /// No description provided for @clearRemoteMessagesSuccess.
  ///
  /// In zh, this message translates to:
  /// **'清理远程消息成功'**
  String get clearRemoteMessagesSuccess;

  /// No description provided for @clearRemoteMessagesFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理远程消息失败: {error}'**
  String clearRemoteMessagesFailed(Object error);

  /// No description provided for @groupConversationDetails.
  ///
  /// In zh, this message translates to:
  /// **'群会话详情'**
  String get groupConversationDetails;

  /// No description provided for @groupMemberList.
  ///
  /// In zh, this message translates to:
  /// **'成员列表'**
  String get groupMemberList;

  /// No description provided for @groupNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'群聊名称'**
  String get groupNameLabel;

  /// No description provided for @groupAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'群公告'**
  String get groupAnnouncement;

  /// No description provided for @groupRemarkLabel.
  ///
  /// In zh, this message translates to:
  /// **'群备注'**
  String get groupRemarkLabel;

  /// No description provided for @groupManagement.
  ///
  /// In zh, this message translates to:
  /// **'群管理'**
  String get groupManagement;

  /// No description provided for @favoriteGroup.
  ///
  /// In zh, this message translates to:
  /// **'保存到通讯录'**
  String get favoriteGroup;

  /// No description provided for @myAliasInGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'我在本群的昵称'**
  String get myAliasInGroupLabel;

  /// No description provided for @showGroupMemberNames.
  ///
  /// In zh, this message translates to:
  /// **'显示群成员昵称'**
  String get showGroupMemberNames;

  /// No description provided for @quitGroupChat.
  ///
  /// In zh, this message translates to:
  /// **'退出群组'**
  String get quitGroupChat;

  /// No description provided for @removeGroupMembers.
  ///
  /// In zh, this message translates to:
  /// **'移除群成员'**
  String get removeGroupMembers;

  /// No description provided for @addGroupMembers.
  ///
  /// In zh, this message translates to:
  /// **'添加群成员'**
  String get addGroupMembers;

  /// No description provided for @selectContacts.
  ///
  /// In zh, this message translates to:
  /// **'选择联系人'**
  String get selectContacts;

  /// No description provided for @modifyGroupNameDialog.
  ///
  /// In zh, this message translates to:
  /// **'修改群名称'**
  String get modifyGroupNameDialog;

  /// No description provided for @modifyGroupRemarkDialog.
  ///
  /// In zh, this message translates to:
  /// **'修改群备注'**
  String get modifyGroupRemarkDialog;

  /// No description provided for @modifyGroupAliasDialog.
  ///
  /// In zh, this message translates to:
  /// **'修改群昵称'**
  String get modifyGroupAliasDialog;

  /// No description provided for @channelDetails.
  ///
  /// In zh, this message translates to:
  /// **'频道详情'**
  String get channelDetails;

  /// No description provided for @unsubscribeChannel.
  ///
  /// In zh, this message translates to:
  /// **'取消订阅'**
  String get unsubscribeChannel;

  /// No description provided for @modifyFailedWithCode.
  ///
  /// In zh, this message translates to:
  /// **'修改失败: {code}'**
  String modifyFailedWithCode(Object code);

  /// No description provided for @chatroom.
  ///
  /// In zh, this message translates to:
  /// **'聊天室'**
  String get chatroom;

  /// No description provided for @robot.
  ///
  /// In zh, this message translates to:
  /// **'机器人'**
  String get robot;

  /// No description provided for @channels.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get channels;

  /// No description provided for @developmentDocumentation.
  ///
  /// In zh, this message translates to:
  /// **'开发文档'**
  String get developmentDocumentation;

  /// No description provided for @sendTo.
  ///
  /// In zh, this message translates to:
  /// **'发送给：'**
  String get sendTo;

  /// No description provided for @leaveMessage.
  ///
  /// In zh, this message translates to:
  /// **'给朋友留言'**
  String get leaveMessage;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @totalMessages.
  ///
  /// In zh, this message translates to:
  /// **'共{count}条消息'**
  String totalMessages(Object count);

  /// No description provided for @messageTag.
  ///
  /// In zh, this message translates to:
  /// **'[消息]'**
  String get messageTag;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// No description provided for @exit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// No description provided for @unsubscribeChannelSuccess.
  ///
  /// In zh, this message translates to:
  /// **'取消订阅成功'**
  String get unsubscribeChannelSuccess;

  /// No description provided for @pickRemindUser.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒的人'**
  String get pickRemindUser;

  /// No description provided for @slideUpToCancel.
  ///
  /// In zh, this message translates to:
  /// **'手指上滑，取消发送'**
  String get slideUpToCancel;

  /// No description provided for @releaseToSend.
  ///
  /// In zh, this message translates to:
  /// **'松开发送'**
  String get releaseToSend;

  /// No description provided for @holdToTalk.
  ///
  /// In zh, this message translates to:
  /// **'按下说话'**
  String get holdToTalk;

  /// No description provided for @noMicrophonePermission.
  ///
  /// In zh, this message translates to:
  /// **'没有权限，请开启权限!'**
  String get noMicrophonePermission;

  /// No description provided for @recordFailed.
  ///
  /// In zh, this message translates to:
  /// **'录音失败: {error}'**
  String recordFailed(Object error);

  /// No description provided for @recordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'录音时间太短'**
  String get recordTooShort;

  /// No description provided for @releaseToCancel.
  ///
  /// In zh, this message translates to:
  /// **'松开取消'**
  String get releaseToCancel;

  /// No description provided for @wfcNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'野火IM 消息通知'**
  String get wfcNotificationTitle;

  /// No description provided for @wfcNotificationDesc.
  ///
  /// In zh, this message translates to:
  /// **'WildfireChat Message Notification'**
  String get wfcNotificationDesc;

  /// No description provided for @newMessage.
  ///
  /// In zh, this message translates to:
  /// **'新消息'**
  String get newMessage;

  /// No description provided for @groupChat.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get groupChat;

  /// No description provided for @channelNewMessage.
  ///
  /// In zh, this message translates to:
  /// **'公众号新消息'**
  String get channelNewMessage;

  /// No description provided for @andOthers.
  ///
  /// In zh, this message translates to:
  /// **' 等'**
  String get andOthers;

  /// No description provided for @requestAddFriend.
  ///
  /// In zh, this message translates to:
  /// **'请求添加你为好友'**
  String get requestAddFriend;

  /// No description provided for @friendRequest.
  ///
  /// In zh, this message translates to:
  /// **'好友申请'**
  String get friendRequest;

  /// No description provided for @kickedOffline.
  ///
  /// In zh, this message translates to:
  /// **'已强制下线'**
  String get kickedOffline;

  /// No description provided for @operateFail.
  ///
  /// In zh, this message translates to:
  /// **'操作失败: {error}'**
  String operateFail(Object error);

  /// No description provided for @pcClient.
  ///
  /// In zh, this message translates to:
  /// **'PC 客户端'**
  String get pcClient;

  /// No description provided for @webClient.
  ///
  /// In zh, this message translates to:
  /// **'Web 客户端'**
  String get webClient;

  /// No description provided for @miniProgram.
  ///
  /// In zh, this message translates to:
  /// **'小程序'**
  String get miniProgram;

  /// No description provided for @unknownDevice.
  ///
  /// In zh, this message translates to:
  /// **'未知设备'**
  String get unknownDevice;

  /// No description provided for @pcOnlineDevices.
  ///
  /// In zh, this message translates to:
  /// **'已登录设备'**
  String get pcOnlineDevices;

  /// No description provided for @noPcOnline.
  ///
  /// In zh, this message translates to:
  /// **'当前没有其他设备登录'**
  String get noPcOnline;

  /// No description provided for @pcOnlineDeviceCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个设备已登录'**
  String pcOnlineDeviceCount(Object count);

  /// No description provided for @mobileMute.
  ///
  /// In zh, this message translates to:
  /// **'手机静音'**
  String get mobileMute;

  /// No description provided for @mobileMuteDesc.
  ///
  /// In zh, this message translates to:
  /// **'PC端登录时，手机端关闭通知提醒'**
  String get mobileMuteDesc;

  /// No description provided for @loginTime.
  ///
  /// In zh, this message translates to:
  /// **'登录时间: '**
  String get loginTime;

  /// No description provided for @backupConversations.
  ///
  /// In zh, this message translates to:
  /// **'备份会话中...'**
  String get backupConversations;

  /// No description provided for @creatingLocalBackup.
  ///
  /// In zh, this message translates to:
  /// **'正在创建本地备份...'**
  String get creatingLocalBackup;

  /// No description provided for @uploadingToPC.
  ///
  /// In zh, this message translates to:
  /// **'正在上传到PC...'**
  String get uploadingToPC;

  /// No description provided for @restoringConversations.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复会话...'**
  String get restoringConversations;

  /// No description provided for @downloadingFiles.
  ///
  /// In zh, this message translates to:
  /// **'正在下载文件...'**
  String get downloadingFiles;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败: {error}'**
  String backupFailed(Object error);

  /// No description provided for @passwordRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要密码'**
  String get passwordRequired;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败: {error}'**
  String restoreFailed(Object error);

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notLoggedIn;

  /// No description provided for @pcResponseTimeout.
  ///
  /// In zh, this message translates to:
  /// **'等待PC响应超时'**
  String get pcResponseTimeout;

  /// No description provided for @fetchBackupListFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取备份列表失败: {error}'**
  String fetchBackupListFailed(Object error);

  /// No description provided for @createLocalBackupFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建本地备份失败'**
  String get createLocalBackupFailed;

  /// No description provided for @uploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @getMetadataFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取元数据失败 {error}'**
  String getMetadataFailed(Object error);

  /// No description provided for @invalidMetadata.
  ///
  /// In zh, this message translates to:
  /// **'无效的元数据'**
  String get invalidMetadata;

  /// No description provided for @passwordRequiredForEncrypted.
  ///
  /// In zh, this message translates to:
  /// **'加密备份需要密码'**
  String get passwordRequiredForEncrypted;

  /// No description provided for @aiRobot.
  ///
  /// In zh, this message translates to:
  /// **'AI 机器人'**
  String get aiRobot;

  /// No description provided for @audioCallAction.
  ///
  /// In zh, this message translates to:
  /// **'音频通话'**
  String get audioCallAction;

  /// No description provided for @videoCallAction.
  ///
  /// In zh, this message translates to:
  /// **'视频通话'**
  String get videoCallAction;

  /// No description provided for @pickGroupMember.
  ///
  /// In zh, this message translates to:
  /// **'选择群成员'**
  String get pickGroupMember;

  /// No description provided for @selectMemberToCall.
  ///
  /// In zh, this message translates to:
  /// **'请选择一位或者多位成员发起通话'**
  String get selectMemberToCall;

  /// No description provided for @callInProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在通话中，无法再次发起！'**
  String get callInProgress;

  /// No description provided for @cannotOpen.
  ///
  /// In zh, this message translates to:
  /// **'无法打开'**
  String get cannotOpen;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @speechToText.
  ///
  /// In zh, this message translates to:
  /// **'转文字'**
  String get speechToText;

  /// No description provided for @recall.
  ///
  /// In zh, this message translates to:
  /// **'撤回'**
  String get recall;

  /// No description provided for @reedit.
  ///
  /// In zh, this message translates to:
  /// **'重新编辑'**
  String get reedit;

  /// No description provided for @recalledMessageNoContent.
  ///
  /// In zh, this message translates to:
  /// **'原消息内容已无法获取'**
  String get recalledMessageNoContent;

  /// No description provided for @multiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get multiSelect;

  /// No description provided for @quote.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get quote;

  /// No description provided for @favoriteAction.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favoriteAction;

  /// No description provided for @favoriteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'收藏成功'**
  String get favoriteSuccess;

  /// No description provided for @favoriteFail.
  ///
  /// In zh, this message translates to:
  /// **'收藏失败: {error}'**
  String favoriteFail(Object error);

  /// No description provided for @audioFileNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'音频文件不可用'**
  String get audioFileNotAvailable;

  /// No description provided for @convertFail.
  ///
  /// In zh, this message translates to:
  /// **'转换失败'**
  String get convertFail;

  /// No description provided for @speechToTextFail.
  ///
  /// In zh, this message translates to:
  /// **'语音转文字失败'**
  String get speechToTextFail;

  /// No description provided for @speechToTextSuccess.
  ///
  /// In zh, this message translates to:
  /// **'转文字成功'**
  String get speechToTextSuccess;

  /// No description provided for @speechToTextError.
  ///
  /// In zh, this message translates to:
  /// **'语音转文字异常: {error}'**
  String speechToTextError(Object error);

  /// No description provided for @convertingToText.
  ///
  /// In zh, this message translates to:
  /// **'转文字中...'**
  String get convertingToText;

  /// No description provided for @inviteReasonHint.
  ///
  /// In zh, this message translates to:
  /// **'请填入申请理由，等待对方同意'**
  String get inviteReasonHint;

  /// No description provided for @inputReason.
  ///
  /// In zh, this message translates to:
  /// **'请输入理由'**
  String get inputReason;

  /// No description provided for @requestSent.
  ///
  /// In zh, this message translates to:
  /// **'请求已发出！'**
  String get requestSent;

  /// No description provided for @networkErrorWithCode.
  ///
  /// In zh, this message translates to:
  /// **'网络错误：{code}'**
  String networkErrorWithCode(Object code);

  /// No description provided for @messageNotExist.
  ///
  /// In zh, this message translates to:
  /// **'消息不存在'**
  String get messageNotExist;

  /// No description provided for @loginWithPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码登录'**
  String get loginWithPassword;

  /// No description provided for @loginWithPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号登录'**
  String get loginWithPhone;

  /// No description provided for @inputPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get inputPassword;

  /// No description provided for @inputVerificationCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get inputVerificationCode;

  /// No description provided for @readAndAgree.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意 '**
  String get readAndAgree;

  /// No description provided for @and.
  ///
  /// In zh, this message translates to:
  /// **' 和 '**
  String get and;

  /// No description provided for @agreePolicyFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先同意用户协议和隐私政策'**
  String get agreePolicyFirst;

  /// No description provided for @loginWithPhoneCode.
  ///
  /// In zh, this message translates to:
  /// **'手机验证码登录'**
  String get loginWithPhoneCode;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @monthDayFormat.
  ///
  /// In zh, this message translates to:
  /// **'MM月dd日'**
  String get monthDayFormat;

  /// No description provided for @yearMonthDayFormat.
  ///
  /// In zh, this message translates to:
  /// **'yyyy年MM月dd日'**
  String get yearMonthDayFormat;

  /// No description provided for @singleChat.
  ///
  /// In zh, this message translates to:
  /// **'单聊<{target}>'**
  String singleChat(Object target);

  /// No description provided for @groupChatWithTarget.
  ///
  /// In zh, this message translates to:
  /// **'群聊<{target}>'**
  String groupChatWithTarget(Object target);

  /// No description provided for @channelWithTarget.
  ///
  /// In zh, this message translates to:
  /// **'频道<{target}>'**
  String channelWithTarget(Object target);

  /// No description provided for @chatroomWithTarget.
  ///
  /// In zh, this message translates to:
  /// **'聊天室-<{target}>'**
  String chatroomWithTarget(Object target);

  /// No description provided for @cannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get cannotOpenLink;

  /// No description provided for @pickMultipleChats.
  ///
  /// In zh, this message translates to:
  /// **'选择多个聊天'**
  String get pickMultipleChats;

  /// No description provided for @pickOneChat.
  ///
  /// In zh, this message translates to:
  /// **'选择一个聊天'**
  String get pickOneChat;

  /// No description provided for @singleSelect.
  ///
  /// In zh, this message translates to:
  /// **'单选'**
  String get singleSelect;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @recentChats.
  ///
  /// In zh, this message translates to:
  /// **'最近聊天'**
  String get recentChats;

  /// No description provided for @contacts.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get contacts;

  /// No description provided for @friends.
  ///
  /// In zh, this message translates to:
  /// **'好友'**
  String get friends;

  /// No description provided for @groups.
  ///
  /// In zh, this message translates to:
  /// **'群组'**
  String get groups;

  /// No description provided for @noSearchResult.
  ///
  /// In zh, this message translates to:
  /// **'没有搜索到结果'**
  String get noSearchResult;

  /// No description provided for @selectedChatsCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择{count}个聊天'**
  String selectedChatsCount(Object count);

  /// No description provided for @sendWithCount.
  ///
  /// In zh, this message translates to:
  /// **'发送({count})'**
  String sendWithCount(Object count);

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get connecting;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @pcLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'{status} 已登录'**
  String pcLoggedIn(Object status);

  /// No description provided for @deleteConversation.
  ///
  /// In zh, this message translates to:
  /// **'删除会话'**
  String get deleteConversation;

  /// No description provided for @untop.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get untop;

  /// No description provided for @top.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get top;

  /// No description provided for @clearUnread.
  ///
  /// In zh, this message translates to:
  /// **'清除未读'**
  String get clearUnread;

  /// No description provided for @setUnread.
  ///
  /// In zh, this message translates to:
  /// **'设为未读'**
  String get setUnread;

  /// No description provided for @draftTag.
  ///
  /// In zh, this message translates to:
  /// **'[草稿]'**
  String get draftTag;

  /// No description provided for @user.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get user;

  /// No description provided for @contact.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get contact;

  /// No description provided for @group.
  ///
  /// In zh, this message translates to:
  /// **'群组'**
  String get group;

  /// No description provided for @channel.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get channel;

  /// No description provided for @others.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get others;

  /// No description provided for @matchedMessageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条消息'**
  String matchedMessageCount(Object count);

  /// No description provided for @noFiles.
  ///
  /// In zh, this message translates to:
  /// **'没有文件'**
  String get noFiles;

  /// No description provided for @unknownFile.
  ///
  /// In zh, this message translates to:
  /// **'未知文件'**
  String get unknownFile;

  /// No description provided for @deleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get deleteSuccess;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get deleteFailed;

  /// No description provided for @imageTag.
  ///
  /// In zh, this message translates to:
  /// **'[图片]'**
  String get imageTag;

  /// No description provided for @videoTag.
  ///
  /// In zh, this message translates to:
  /// **'[视频]'**
  String get videoTag;

  /// No description provided for @voiceTag.
  ///
  /// In zh, this message translates to:
  /// **'[语音]'**
  String get voiceTag;

  /// No description provided for @chatHistoryTag.
  ///
  /// In zh, this message translates to:
  /// **'[聊天记录]'**
  String get chatHistoryTag;

  /// No description provided for @fileTag.
  ///
  /// In zh, this message translates to:
  /// **'[文件]'**
  String get fileTag;

  /// No description provided for @linkTag.
  ///
  /// In zh, this message translates to:
  /// **'[链接]'**
  String get linkTag;

  /// No description provided for @deleteFavorite.
  ///
  /// In zh, this message translates to:
  /// **'删除收藏'**
  String get deleteFavorite;

  /// No description provided for @deleteFavoriteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条收藏吗？'**
  String get deleteFavoriteConfirm;

  /// No description provided for @myFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get myFavorites;

  /// No description provided for @noFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get noFavorites;

  /// No description provided for @fileLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件: '**
  String get fileLabel;

  /// No description provided for @linkLabel.
  ///
  /// In zh, this message translates to:
  /// **'链接: '**
  String get linkLabel;

  /// No description provided for @favoritesAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get favoritesAll;

  /// No description provided for @favoritesFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get favoritesFile;

  /// No description provided for @favoritesMedia.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get favoritesMedia;

  /// No description provided for @favoritesComposite.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录'**
  String get favoritesComposite;

  /// No description provided for @unsupportedMessageType.
  ///
  /// In zh, this message translates to:
  /// **'不支持的消息类型'**
  String get unsupportedMessageType;

  /// No description provided for @fileRecords.
  ///
  /// In zh, this message translates to:
  /// **'文件记录'**
  String get fileRecords;

  /// No description provided for @allFiles.
  ///
  /// In zh, this message translates to:
  /// **'所有文件'**
  String get allFiles;

  /// No description provided for @myFiles.
  ///
  /// In zh, this message translates to:
  /// **'我的文件'**
  String get myFiles;

  /// No description provided for @userFiles.
  ///
  /// In zh, this message translates to:
  /// **'用户文件'**
  String get userFiles;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入开始搜索'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入内容进行搜索'**
  String get searchPrompt;

  /// No description provided for @readReceiptDetail.
  ///
  /// In zh, this message translates to:
  /// **'消息回执详情'**
  String get readReceiptDetail;

  /// No description provided for @readCount.
  ///
  /// In zh, this message translates to:
  /// **'已读 ({count})'**
  String readCount(Object count);

  /// No description provided for @unreadCount.
  ///
  /// In zh, this message translates to:
  /// **'未读 ({count})'**
  String unreadCount(Object count);

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// No description provided for @addToBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'加入黑名单'**
  String get addToBlacklist;

  /// No description provided for @removeFromBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'移出黑名单'**
  String get removeFromBlacklist;

  /// No description provided for @deleteFriend.
  ///
  /// In zh, this message translates to:
  /// **'删除好友'**
  String get deleteFriend;

  /// No description provided for @deleteFriendConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除好友后，将同时删除与该好友的聊天记录'**
  String get deleteFriendConfirm;

  /// No description provided for @setStarredFriend.
  ///
  /// In zh, this message translates to:
  /// **'设为星标朋友'**
  String get setStarredFriend;

  /// No description provided for @cancelStarredFriend.
  ///
  /// In zh, this message translates to:
  /// **'取消星标朋友'**
  String get cancelStarredFriend;

  /// No description provided for @friendRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'好友请求已发送'**
  String get friendRequestSent;

  /// No description provided for @viewAllFriendRequests.
  ///
  /// In zh, this message translates to:
  /// **'查看全部好友请求'**
  String get viewAllFriendRequests;

  /// No description provided for @remark.
  ///
  /// In zh, this message translates to:
  /// **'备注名'**
  String get remark;

  /// No description provided for @favFriend.
  ///
  /// In zh, this message translates to:
  /// **'星标好友'**
  String get favFriend;

  /// No description provided for @contactCategory.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get contactCategory;

  /// No description provided for @starredContact.
  ///
  /// In zh, this message translates to:
  /// **'星标联系人'**
  String get starredContact;

  /// No description provided for @doneWithCount.
  ///
  /// In zh, this message translates to:
  /// **'完成({count})'**
  String doneWithCount(Object count);

  /// No description provided for @maxUserLimit.
  ///
  /// In zh, this message translates to:
  /// **'超过最大人数限制'**
  String get maxUserLimit;

  /// No description provided for @selectFromOrganization.
  ///
  /// In zh, this message translates to:
  /// **'从组织架构选择'**
  String get selectFromOrganization;

  /// No description provided for @pickedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 人'**
  String pickedCount(Object count);

  /// No description provided for @pickContactHint.
  ///
  /// In zh, this message translates to:
  /// **'从左侧勾选联系人'**
  String get pickContactHint;

  /// No description provided for @collection.
  ///
  /// In zh, this message translates to:
  /// **'群接龙'**
  String get collection;

  /// No description provided for @createCollection.
  ///
  /// In zh, this message translates to:
  /// **'发起接龙'**
  String get createCollection;

  /// No description provided for @collectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'接龙标题'**
  String get collectionTitle;

  /// No description provided for @collectionTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入接龙标题'**
  String get collectionTitleHint;

  /// No description provided for @collectionDesc.
  ///
  /// In zh, this message translates to:
  /// **'接龙描述'**
  String get collectionDesc;

  /// No description provided for @collectionDescHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入接龙描述（选填）'**
  String get collectionDescHint;

  /// No description provided for @collectionTemplate.
  ///
  /// In zh, this message translates to:
  /// **'参与模板'**
  String get collectionTemplate;

  /// No description provided for @collectionTemplateLabel.
  ///
  /// In zh, this message translates to:
  /// **'模板: '**
  String get collectionTemplateLabel;

  /// No description provided for @collectionTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'设置参与模板，方便群成员按格式填写'**
  String get collectionTemplateHint;

  /// No description provided for @collectionTemplateExample.
  ///
  /// In zh, this message translates to:
  /// **'如：姓名-电话'**
  String get collectionTemplateExample;

  /// No description provided for @expireSetting.
  ///
  /// In zh, this message translates to:
  /// **'过期设置'**
  String get expireSetting;

  /// No description provided for @noExpire.
  ///
  /// In zh, this message translates to:
  /// **'无限期'**
  String get noExpire;

  /// No description provided for @setExpire.
  ///
  /// In zh, this message translates to:
  /// **'设置过期时间'**
  String get setExpire;

  /// No description provided for @expireDate.
  ///
  /// In zh, this message translates to:
  /// **'过期日期'**
  String get expireDate;

  /// No description provided for @expireTime.
  ///
  /// In zh, this message translates to:
  /// **'过期时间'**
  String get expireTime;

  /// No description provided for @pleaseSelect.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get pleaseSelect;

  /// No description provided for @expireTimeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'过期时间必须大于当前时间'**
  String get expireTimeInvalid;

  /// No description provided for @collectionTag.
  ///
  /// In zh, this message translates to:
  /// **'群接龙'**
  String get collectionTag;

  /// No description provided for @collectionPeopleCount.
  ///
  /// In zh, this message translates to:
  /// **'人'**
  String get collectionPeopleCount;

  /// No description provided for @collectionStatusActive.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get collectionStatusActive;

  /// No description provided for @collectionStatusEnded.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get collectionStatusEnded;

  /// No description provided for @collectionStatusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get collectionStatusCancelled;

  /// No description provided for @collectionJoinAction.
  ///
  /// In zh, this message translates to:
  /// **'参与接龙'**
  String get collectionJoinAction;

  /// No description provided for @collectionEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无参与，快来抢沙发吧~'**
  String get collectionEmptyHint;

  /// No description provided for @collectionMoreParticipants.
  ///
  /// In zh, this message translates to:
  /// **'等{count}人参与'**
  String collectionMoreParticipants(Object count);

  /// No description provided for @collectionClickToView.
  ///
  /// In zh, this message translates to:
  /// **'点击查看详情'**
  String get collectionClickToView;

  /// No description provided for @collectionDetail.
  ///
  /// In zh, this message translates to:
  /// **'接龙详情'**
  String get collectionDetail;

  /// No description provided for @collectionCreator.
  ///
  /// In zh, this message translates to:
  /// **'发起者'**
  String get collectionCreator;

  /// No description provided for @collectionCreatorSuffix.
  ///
  /// In zh, this message translates to:
  /// **'发起的接龙'**
  String get collectionCreatorSuffix;

  /// No description provided for @collectionJoinHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入参与内容'**
  String get collectionJoinHint;

  /// No description provided for @submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @confirmDeleteEntry.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除你的参与记录吗？'**
  String get confirmDeleteEntry;

  /// No description provided for @collectionServiceNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'接龙服务未配置'**
  String get collectionServiceNotConfigured;

  /// No description provided for @collectionLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载接龙详情失败'**
  String get collectionLoadFailed;

  /// No description provided for @collectionJoinSuccess.
  ///
  /// In zh, this message translates to:
  /// **'参与成功'**
  String get collectionJoinSuccess;

  /// No description provided for @collectionJoinFailed.
  ///
  /// In zh, this message translates to:
  /// **'参与失败'**
  String get collectionJoinFailed;

  /// No description provided for @collectionUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'更新成功'**
  String get collectionUpdateSuccess;

  /// No description provided for @collectionUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get collectionUpdateFailed;

  /// No description provided for @collectionDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get collectionDeleteSuccess;

  /// No description provided for @collectionNotInGroup.
  ///
  /// In zh, this message translates to:
  /// **'你已不在该群组中'**
  String get collectionNotInGroup;

  /// No description provided for @collectionCreateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'接龙创建成功'**
  String get collectionCreateSuccess;

  /// No description provided for @collectionCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建接龙失败'**
  String get collectionCreateFailed;

  /// No description provided for @collectionEndTime.
  ///
  /// In zh, this message translates to:
  /// **'截止时间'**
  String get collectionEndTime;

  /// No description provided for @collectionNoEndTime.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间'**
  String get collectionNoEndTime;

  /// No description provided for @poll.
  ///
  /// In zh, this message translates to:
  /// **'群投票'**
  String get poll;

  /// No description provided for @createPoll.
  ///
  /// In zh, this message translates to:
  /// **'发起投票'**
  String get createPoll;

  /// No description provided for @createPollSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'创建一个新的群投票'**
  String get createPollSubtitle;

  /// No description provided for @myPollsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看我发起的投票'**
  String get myPollsSubtitle;

  /// No description provided for @pollEmptyList.
  ///
  /// In zh, this message translates to:
  /// **'暂无投票记录'**
  String get pollEmptyList;

  /// No description provided for @pollHasVoted.
  ///
  /// In zh, this message translates to:
  /// **'已投票'**
  String get pollHasVoted;

  /// No description provided for @pollDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个投票吗？'**
  String get pollDeleteConfirm;

  /// No description provided for @myPolls.
  ///
  /// In zh, this message translates to:
  /// **'我的投票'**
  String get myPolls;

  /// No description provided for @pollTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入投票标题'**
  String get pollTitleHint;

  /// No description provided for @pollDescHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入投票描述（选填）'**
  String get pollDescHint;

  /// No description provided for @pollOption.
  ///
  /// In zh, this message translates to:
  /// **'选项'**
  String get pollOption;

  /// No description provided for @pollAddOption.
  ///
  /// In zh, this message translates to:
  /// **'添加选项'**
  String get pollAddOption;

  /// No description provided for @pollType.
  ///
  /// In zh, this message translates to:
  /// **'投票类型'**
  String get pollType;

  /// No description provided for @pollSingleChoice.
  ///
  /// In zh, this message translates to:
  /// **'单选'**
  String get pollSingleChoice;

  /// No description provided for @pollMultiChoice.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get pollMultiChoice;

  /// No description provided for @pollMaxSelect.
  ///
  /// In zh, this message translates to:
  /// **'最多选几项'**
  String get pollMaxSelect;

  /// No description provided for @pollOptions.
  ///
  /// In zh, this message translates to:
  /// **'项'**
  String get pollOptions;

  /// No description provided for @pollAnonymousVote.
  ///
  /// In zh, this message translates to:
  /// **'匿名投票'**
  String get pollAnonymousVote;

  /// No description provided for @pollAnonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名'**
  String get pollAnonymous;

  /// No description provided for @pollShowResult.
  ///
  /// In zh, this message translates to:
  /// **'始终显示结果'**
  String get pollShowResult;

  /// No description provided for @pollEndTime.
  ///
  /// In zh, this message translates to:
  /// **'截止时间'**
  String get pollEndTime;

  /// No description provided for @pollNoEndTime.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间'**
  String get pollNoEndTime;

  /// No description provided for @pollMaxOptionsLimit.
  ///
  /// In zh, this message translates to:
  /// **'最多只能添加{count}个选项'**
  String pollMaxOptionsLimit(Object count);

  /// No description provided for @pollMinOptionsRequired.
  ///
  /// In zh, this message translates to:
  /// **'至少需要{count}个选项'**
  String pollMinOptionsRequired(Object count);

  /// No description provided for @pollSelectOption.
  ///
  /// In zh, this message translates to:
  /// **'请选择至少一个选项'**
  String get pollSelectOption;

  /// No description provided for @pollSubmitVote.
  ///
  /// In zh, this message translates to:
  /// **'提交投票'**
  String get pollSubmitVote;

  /// No description provided for @pollVotesCount.
  ///
  /// In zh, this message translates to:
  /// **'票'**
  String get pollVotesCount;

  /// No description provided for @pollPeopleCount.
  ///
  /// In zh, this message translates to:
  /// **'人参与'**
  String get pollPeopleCount;

  /// No description provided for @pollStatusActive.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get pollStatusActive;

  /// No description provided for @pollStatusEnded.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get pollStatusEnded;

  /// No description provided for @pollStatusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get pollStatusCancelled;

  /// No description provided for @pollJoinAction.
  ///
  /// In zh, this message translates to:
  /// **'参与投票'**
  String get pollJoinAction;

  /// No description provided for @pollViewResult.
  ///
  /// In zh, this message translates to:
  /// **'查看结果'**
  String get pollViewResult;

  /// No description provided for @pollCreatorSuffix.
  ///
  /// In zh, this message translates to:
  /// **'发起的投票'**
  String get pollCreatorSuffix;

  /// No description provided for @pollTotalVotes.
  ///
  /// In zh, this message translates to:
  /// **'总票数'**
  String get pollTotalVotes;

  /// No description provided for @pollVotes.
  ///
  /// In zh, this message translates to:
  /// **'票'**
  String get pollVotes;

  /// No description provided for @pollDetail.
  ///
  /// In zh, this message translates to:
  /// **'投票详情'**
  String get pollDetail;

  /// No description provided for @pollLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载投票详情失败'**
  String get pollLoadFailed;

  /// No description provided for @pollServiceNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'投票服务未配置'**
  String get pollServiceNotConfigured;

  /// No description provided for @pollVoteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'投票成功'**
  String get pollVoteSuccess;

  /// No description provided for @pollVoteFailed.
  ///
  /// In zh, this message translates to:
  /// **'投票失败'**
  String get pollVoteFailed;

  /// No description provided for @pollCloseConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要结束这个投票吗？结束后将无法继续投票'**
  String get pollCloseConfirm;

  /// No description provided for @pollCloseSuccess.
  ///
  /// In zh, this message translates to:
  /// **'投票已结束'**
  String get pollCloseSuccess;

  /// No description provided for @pollCloseFailed.
  ///
  /// In zh, this message translates to:
  /// **'结束投票失败'**
  String get pollCloseFailed;

  /// No description provided for @pollCreateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'投票创建成功'**
  String get pollCreateSuccess;

  /// No description provided for @pollCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建投票失败'**
  String get pollCreateFailed;

  /// No description provided for @pollMaxSelectLimit.
  ///
  /// In zh, this message translates to:
  /// **'最多只能选择{count}个选项'**
  String pollMaxSelectLimit(Object count);

  /// No description provided for @pollClose.
  ///
  /// In zh, this message translates to:
  /// **'结束投票'**
  String get pollClose;

  /// No description provided for @pollDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除投票'**
  String get pollDelete;

  /// No description provided for @pollExport.
  ///
  /// In zh, this message translates to:
  /// **'导出明细'**
  String get pollExport;

  /// No description provided for @pollNamed.
  ///
  /// In zh, this message translates to:
  /// **'实名'**
  String get pollNamed;

  /// No description provided for @pollVoterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}人参与'**
  String pollVoterCount(Object count);

  /// No description provided for @pollAlreadyVoted.
  ///
  /// In zh, this message translates to:
  /// **'已投票'**
  String get pollAlreadyVoted;

  /// No description provided for @pollOptionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'投票选项'**
  String get pollOptionsTitle;

  /// No description provided for @pollSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选{count}/{max}'**
  String pollSelectedCount(Object count, Object max);

  /// No description provided for @pollDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'投票已删除'**
  String get pollDeleteSuccess;

  /// No description provided for @pollDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除投票失败'**
  String get pollDeleteFailed;

  /// No description provided for @pollExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get pollExportFailed;

  /// No description provided for @pollNoVoterDetails.
  ///
  /// In zh, this message translates to:
  /// **'暂无投票明细'**
  String get pollNoVoterDetails;

  /// No description provided for @pollShareDetails.
  ///
  /// In zh, this message translates to:
  /// **'投票明细'**
  String get pollShareDetails;

  /// No description provided for @pollCsvOption.
  ///
  /// In zh, this message translates to:
  /// **'选项'**
  String get pollCsvOption;

  /// No description provided for @pollCsvUser.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get pollCsvUser;

  /// No description provided for @pollCsvTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get pollCsvTime;

  /// No description provided for @pollDetailsSuffix.
  ///
  /// In zh, this message translates to:
  /// **'投票明细'**
  String get pollDetailsSuffix;

  /// No description provided for @pollDefaultFileName.
  ///
  /// In zh, this message translates to:
  /// **'投票'**
  String get pollDefaultFileName;

  /// No description provided for @pollCreatorFormat.
  ///
  /// In zh, this message translates to:
  /// **'由{creatorName}发起'**
  String pollCreatorFormat(Object creatorName);

  /// No description provided for @pollDaysLeft.
  ///
  /// In zh, this message translates to:
  /// **'还剩{count}天'**
  String pollDaysLeft(Object count);

  /// No description provided for @pollHoursLeft.
  ///
  /// In zh, this message translates to:
  /// **'还剩{count}小时'**
  String pollHoursLeft(Object count);

  /// No description provided for @pollMinutesLeft.
  ///
  /// In zh, this message translates to:
  /// **'还剩{count}分钟'**
  String pollMinutesLeft(Object count);

  /// No description provided for @pollNoDeadline.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间'**
  String get pollNoDeadline;

  /// No description provided for @publish.
  ///
  /// In zh, this message translates to:
  /// **'发布'**
  String get publish;

  /// No description provided for @pickFriendsToStartChat.
  ///
  /// In zh, this message translates to:
  /// **'请选择一位或者多位好友发起聊天'**
  String get pickFriendsToStartChat;

  /// No description provided for @creatingGroup.
  ///
  /// In zh, this message translates to:
  /// **'群组创建中...'**
  String get creatingGroup;

  /// No description provided for @createGroupChat.
  ///
  /// In zh, this message translates to:
  /// **'创建群聊'**
  String get createGroupChat;

  /// No description provided for @createAndSend.
  ///
  /// In zh, this message translates to:
  /// **'创建并发送'**
  String get createAndSend;

  /// No description provided for @forwardSendSeparately.
  ///
  /// In zh, this message translates to:
  /// **'分别发送给'**
  String get forwardSendSeparately;

  /// No description provided for @forwardSendMerged.
  ///
  /// In zh, this message translates to:
  /// **'合并发送给'**
  String get forwardSendMerged;

  /// No description provided for @pickTargetsFromLeft.
  ///
  /// In zh, this message translates to:
  /// **'请在左侧选择联系人或群聊'**
  String get pickTargetsFromLeft;

  /// No description provided for @selectedContactsCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择{count}个联系人'**
  String selectedContactsCount(Object count);

  /// No description provided for @pickContactsToCreateGroup.
  ///
  /// In zh, this message translates to:
  /// **'请选择群成员'**
  String get pickContactsToCreateGroup;

  /// No description provided for @createGroupFail.
  ///
  /// In zh, this message translates to:
  /// **'创建失败：{error}'**
  String createGroupFail(Object error);

  /// No description provided for @groupNameEtc.
  ///
  /// In zh, this message translates to:
  /// **'{names}等'**
  String groupNameEtc(Object names);

  /// No description provided for @audioVideoCall.
  ///
  /// In zh, this message translates to:
  /// **'音视频通话'**
  String get audioVideoCall;

  /// No description provided for @callOngoingClickRestore.
  ///
  /// In zh, this message translates to:
  /// **'通话中 - 点击恢复'**
  String get callOngoingClickRestore;

  /// No description provided for @sendFile.
  ///
  /// In zh, this message translates to:
  /// **'发送文件'**
  String get sendFile;

  /// No description provided for @confirmSendFile.
  ///
  /// In zh, this message translates to:
  /// **'确定要发送 \"{fileName}\" 吗？'**
  String confirmSendFile(Object fileName);

  /// No description provided for @desktopOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前界面仅支持桌面端'**
  String get desktopOnly;

  /// No description provided for @sendCodeFailWithError.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码失败: {error}'**
  String sendCodeFailWithError(Object error);

  /// No description provided for @showWindow.
  ///
  /// In zh, this message translates to:
  /// **'显示窗口'**
  String get showWindow;

  /// No description provided for @trayUnreadTooltip.
  ///
  /// In zh, this message translates to:
  /// **'野火IM {count} 条未读消息'**
  String trayUnreadTooltip(Object count);

  /// No description provided for @previousImage.
  ///
  /// In zh, this message translates to:
  /// **'上一张 (←)'**
  String get previousImage;

  /// No description provided for @nextImage.
  ///
  /// In zh, this message translates to:
  /// **'下一张 (→)'**
  String get nextImage;

  /// No description provided for @rotateLeft.
  ///
  /// In zh, this message translates to:
  /// **'向左旋转'**
  String get rotateLeft;

  /// No description provided for @rotateRight.
  ///
  /// In zh, this message translates to:
  /// **'向右旋转'**
  String get rotateRight;

  /// No description provided for @saveAs.
  ///
  /// In zh, this message translates to:
  /// **'另存为...'**
  String get saveAs;

  /// No description provided for @saveFile.
  ///
  /// In zh, this message translates to:
  /// **'保存文件'**
  String get saveFile;

  /// No description provided for @saveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get saveSuccess;

  /// No description provided for @saveFailSourceMissing.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: 找不到源文件或链接'**
  String get saveFailSourceMissing;

  /// No description provided for @saveFail.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String saveFail(Object error);

  /// No description provided for @callStatusEnded.
  ///
  /// In zh, this message translates to:
  /// **'通话结束'**
  String get callStatusEnded;

  /// No description provided for @callStatusCalling.
  ///
  /// In zh, this message translates to:
  /// **'正在呼叫...'**
  String get callStatusCalling;

  /// No description provided for @callIncomingInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请你进行语音通话'**
  String get callIncomingInvite;

  /// No description provided for @callStatusConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get callStatusConnecting;

  /// No description provided for @callDecline.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get callDecline;

  /// No description provided for @callAnswer.
  ///
  /// In zh, this message translates to:
  /// **'接听'**
  String get callAnswer;

  /// No description provided for @callAnswerAudio.
  ///
  /// In zh, this message translates to:
  /// **'语音接听'**
  String get callAnswerAudio;

  /// No description provided for @callAnswerVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频接听'**
  String get callAnswerVideo;

  /// No description provided for @callMute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get callMute;

  /// No description provided for @callHangup.
  ///
  /// In zh, this message translates to:
  /// **'挂断'**
  String get callHangup;

  /// No description provided for @callSwitchCamera.
  ///
  /// In zh, this message translates to:
  /// **'翻转'**
  String get callSwitchCamera;

  /// No description provided for @callSpeaker.
  ///
  /// In zh, this message translates to:
  /// **'免提'**
  String get callSpeaker;

  /// No description provided for @callCameraOn.
  ///
  /// In zh, this message translates to:
  /// **'开启摄像头'**
  String get callCameraOn;

  /// No description provided for @callCameraOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭摄像头'**
  String get callCameraOff;

  /// No description provided for @openFile.
  ///
  /// In zh, this message translates to:
  /// **'打开文件'**
  String get openFile;

  /// No description provided for @deleteFileRecordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条文件记录吗？'**
  String get deleteFileRecordConfirm;

  /// No description provided for @fileRecordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'文件记录已删除'**
  String get fileRecordDeleted;

  /// No description provided for @deleteFileRecordFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除文件记录失败'**
  String get deleteFileRecordFailed;

  /// No description provided for @searchFiles.
  ///
  /// In zh, this message translates to:
  /// **'搜索文件'**
  String get searchFiles;

  /// No description provided for @fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeNormal.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get fontSizeNormal;

  /// No description provided for @fontSizeMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get fontSizeMedium;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontSizeLarge;

  /// No description provided for @fontSizeExtraLarge.
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get fontSizeExtraLarge;

  /// No description provided for @fontSizePreviewIncoming.
  ///
  /// In zh, this message translates to:
  /// **'预览字体大小'**
  String get fontSizePreviewIncoming;

  /// No description provided for @fontSizePreviewOutgoing.
  ///
  /// In zh, this message translates to:
  /// **'拖动下方的滑块，可设置字体大小'**
  String get fontSizePreviewOutgoing;

  /// No description provided for @fontSizePreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'设置后，会话中的消息、联系人列表等都将按此大小显示。'**
  String get fontSizePreviewHint;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @chatLinks.
  ///
  /// In zh, this message translates to:
  /// **'会话链接'**
  String get chatLinks;

  /// No description provided for @noLinks.
  ///
  /// In zh, this message translates to:
  /// **'暂无链接'**
  String get noLinks;

  /// No description provided for @joinGroupRequests.
  ///
  /// In zh, this message translates to:
  /// **'入群申请'**
  String get joinGroupRequests;

  /// No description provided for @noJoinGroupRequests.
  ///
  /// In zh, this message translates to:
  /// **'暂无入群申请'**
  String get noJoinGroupRequests;

  /// No description provided for @joinGroupReason.
  ///
  /// In zh, this message translates to:
  /// **'申请理由'**
  String get joinGroupReason;

  /// No description provided for @agree.
  ///
  /// In zh, this message translates to:
  /// **'同意'**
  String get agree;

  /// No description provided for @reject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get reject;

  /// No description provided for @clearJoinGroupRequests.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearJoinGroupRequests;

  /// No description provided for @accepted.
  ///
  /// In zh, this message translates to:
  /// **'已通过'**
  String get accepted;

  /// No description provided for @rejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get rejected;

  /// No description provided for @expired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get expired;

  /// No description provided for @newJoinGroupRequestCount.
  ///
  /// In zh, this message translates to:
  /// **'有{count}条新加群申请'**
  String newJoinGroupRequestCount(Object count);

  /// No description provided for @joinGroupRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送给管理员，请等待管理员批准'**
  String get joinGroupRequestSent;

  /// No description provided for @sendFailure.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get sendFailure;

  /// No description provided for @joinGroupVerificationEnabled.
  ///
  /// In zh, this message translates to:
  /// **'该群已开启入群验证'**
  String get joinGroupVerificationEnabled;

  /// No description provided for @pleaseInputJoinGroupReason.
  ///
  /// In zh, this message translates to:
  /// **'请输入入群理由'**
  String get pleaseInputJoinGroupReason;

  /// No description provided for @requestJoinGroup.
  ///
  /// In zh, this message translates to:
  /// **'{name} 请求加入群聊'**
  String requestJoinGroup(Object name);

  /// No description provided for @inviteJoinGroup.
  ///
  /// In zh, this message translates to:
  /// **'{inviter} 邀请 {member} 加入群聊'**
  String inviteJoinGroup(Object inviter, Object member);

  /// No description provided for @deleteJoinGroupRequest.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteJoinGroupRequest;

  /// No description provided for @managerSetting.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get managerSetting;

  /// No description provided for @muteSetting.
  ///
  /// In zh, this message translates to:
  /// **'禁言设置'**
  String get muteSetting;

  /// No description provided for @allowTemporarySession.
  ///
  /// In zh, this message translates to:
  /// **'允许临时会话'**
  String get allowTemporarySession;

  /// No description provided for @joinGroupPermission.
  ///
  /// In zh, this message translates to:
  /// **'加群权限'**
  String get joinGroupPermission;

  /// No description provided for @freeToJoin.
  ///
  /// In zh, this message translates to:
  /// **'自由加入'**
  String get freeToJoin;

  /// No description provided for @memberInviteOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅群成员邀请'**
  String get memberInviteOnly;

  /// No description provided for @managerInviteOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅管理邀请'**
  String get managerInviteOnly;

  /// No description provided for @needManagerVerify.
  ///
  /// In zh, this message translates to:
  /// **'需要管理审批'**
  String get needManagerVerify;

  /// No description provided for @groupVisible.
  ///
  /// In zh, this message translates to:
  /// **'群可见性'**
  String get groupVisible;

  /// No description provided for @searchable.
  ///
  /// In zh, this message translates to:
  /// **'可被搜索'**
  String get searchable;

  /// No description provided for @notSearchable.
  ///
  /// In zh, this message translates to:
  /// **'不可被搜索'**
  String get notSearchable;

  /// No description provided for @groupHistoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'历史消息'**
  String get groupHistoryMessage;

  /// No description provided for @groupMaxMember.
  ///
  /// In zh, this message translates to:
  /// **'最大成员数'**
  String get groupMaxMember;

  /// No description provided for @addManager.
  ///
  /// In zh, this message translates to:
  /// **'添加管理员'**
  String get addManager;

  /// No description provided for @removeManager.
  ///
  /// In zh, this message translates to:
  /// **'移除管理员'**
  String get removeManager;

  /// No description provided for @mutedMembers.
  ///
  /// In zh, this message translates to:
  /// **'禁言成员'**
  String get mutedMembers;

  /// No description provided for @allowedMembers.
  ///
  /// In zh, this message translates to:
  /// **'白名单成员'**
  String get allowedMembers;

  /// No description provided for @addMutedMember.
  ///
  /// In zh, this message translates to:
  /// **'添加禁言成员'**
  String get addMutedMember;

  /// No description provided for @addAllowedMember.
  ///
  /// In zh, this message translates to:
  /// **'添加白名单成员'**
  String get addAllowedMember;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @noCandidateForManager.
  ///
  /// In zh, this message translates to:
  /// **'没有可添加为管理员的成员'**
  String get noCandidateForManager;

  /// No description provided for @noCandidateForMute.
  ///
  /// In zh, this message translates to:
  /// **'没有可选择的成员'**
  String get noCandidateForMute;

  /// No description provided for @unmuteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已取消禁言'**
  String get unmuteSuccess;

  /// No description provided for @unallowSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已移除白名单'**
  String get unallowSuccess;

  /// No description provided for @removeManagerSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已移除管理员'**
  String get removeManagerSuccess;

  /// No description provided for @groupOwner.
  ///
  /// In zh, this message translates to:
  /// **'群主'**
  String get groupOwner;

  /// No description provided for @groupManager.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get groupManager;

  /// No description provided for @muteAllMembers.
  ///
  /// In zh, this message translates to:
  /// **'全员禁言'**
  String get muteAllMembers;

  /// No description provided for @noOtherMembersToTransfer.
  ///
  /// In zh, this message translates to:
  /// **'群中没有其他成员可转让'**
  String get noOtherMembersToTransfer;

  /// No description provided for @transferGroupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'转让群组成功'**
  String get transferGroupSuccess;

  /// No description provided for @cloudDrive.
  ///
  /// In zh, this message translates to:
  /// **'云盘'**
  String get cloudDrive;

  /// No description provided for @pickDestination.
  ///
  /// In zh, this message translates to:
  /// **'选择目标位置'**
  String get pickDestination;

  /// No description provided for @panServiceNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'云盘服务未配置'**
  String get panServiceNotConfigured;

  /// No description provided for @loadFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，请稍后重试'**
  String get loadFailedRetry;

  /// No description provided for @noPanSpaces.
  ///
  /// In zh, this message translates to:
  /// **'没有网盘空间'**
  String get noPanSpaces;

  /// No description provided for @panFileCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}个文件'**
  String panFileCount(Object count);

  /// No description provided for @panGlobalPublicSpace.
  ///
  /// In zh, this message translates to:
  /// **'全局公共空间'**
  String get panGlobalPublicSpace;

  /// No description provided for @panMyPublicSpace.
  ///
  /// In zh, this message translates to:
  /// **'我的公共空间'**
  String get panMyPublicSpace;

  /// No description provided for @panMyPrivateSpace.
  ///
  /// In zh, this message translates to:
  /// **'我的个人空间'**
  String get panMyPrivateSpace;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @noFilesYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无文件'**
  String get noFilesYet;

  /// No description provided for @panItemCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}项'**
  String panItemCount(Object count);

  /// No description provided for @panCannotMoveFolderIntoItself.
  ///
  /// In zh, this message translates to:
  /// **'不能将文件夹移动到自身'**
  String get panCannotMoveFolderIntoItself;

  /// No description provided for @panCannotCopyFolderIntoItself.
  ///
  /// In zh, this message translates to:
  /// **'不能将文件夹复制到自身'**
  String get panCannotCopyFolderIntoItself;

  /// No description provided for @panGetDownloadUrlFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取下载链接失败'**
  String get panGetDownloadUrlFailed;

  /// No description provided for @uploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中...'**
  String get uploading;

  /// No description provided for @cancelUpload.
  ///
  /// In zh, this message translates to:
  /// **'取消上传'**
  String get cancelUpload;

  /// No description provided for @uploadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上传成功'**
  String get uploadSuccess;

  /// No description provided for @uploadCancelled.
  ///
  /// In zh, this message translates to:
  /// **'上传已取消'**
  String get uploadCancelled;

  /// No description provided for @uploadFail.
  ///
  /// In zh, this message translates to:
  /// **'上传失败'**
  String get uploadFail;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get folderName;

  /// No description provided for @createSuccess.
  ///
  /// In zh, this message translates to:
  /// **'创建成功'**
  String get createSuccess;

  /// No description provided for @createFail.
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get createFail;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @newName.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get newName;

  /// No description provided for @renameSuccess.
  ///
  /// In zh, this message translates to:
  /// **'重命名成功'**
  String get renameSuccess;

  /// No description provided for @renameFail.
  ///
  /// In zh, this message translates to:
  /// **'重命名失败'**
  String get renameFail;

  /// No description provided for @panNoSpaceToSave.
  ///
  /// In zh, this message translates to:
  /// **'没有可转存的空间'**
  String get panNoSpaceToSave;

  /// No description provided for @panLoadSpacesFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载空间失败'**
  String get panLoadSpacesFailed;

  /// No description provided for @panDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'转存'**
  String get panDuplicate;

  /// No description provided for @panDuplicateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'转存成功'**
  String get panDuplicateSuccess;

  /// No description provided for @panDuplicateFail.
  ///
  /// In zh, this message translates to:
  /// **'转存失败'**
  String get panDuplicateFail;

  /// No description provided for @panCannotMoveToSameLocation.
  ///
  /// In zh, this message translates to:
  /// **'不能将文件移动到原位置'**
  String get panCannotMoveToSameLocation;

  /// No description provided for @moveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'移动成功'**
  String get moveSuccess;

  /// No description provided for @moveFail.
  ///
  /// In zh, this message translates to:
  /// **'移动失败'**
  String get moveFail;

  /// No description provided for @panCannotCopyToSameLocation.
  ///
  /// In zh, this message translates to:
  /// **'不能将文件复制到原位置'**
  String get panCannotCopyToSameLocation;

  /// No description provided for @copySuccess.
  ///
  /// In zh, this message translates to:
  /// **'复制成功'**
  String get copySuccess;

  /// No description provided for @copyFail.
  ///
  /// In zh, this message translates to:
  /// **'复制失败'**
  String get copyFail;

  /// No description provided for @deleteFileConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认要删除“{name}”吗？'**
  String deleteFileConfirm(Object name);

  /// No description provided for @downloadOrOpen.
  ///
  /// In zh, this message translates to:
  /// **'下载/打开'**
  String get downloadOrOpen;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @move.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get move;

  /// No description provided for @general.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get general;

  /// No description provided for @appearanceAndTheme.
  ///
  /// In zh, this message translates to:
  /// **'外观与主题'**
  String get appearanceAndTheme;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notifications;

  /// No description provided for @accountAndSecurity.
  ///
  /// In zh, this message translates to:
  /// **'账号与安全'**
  String get accountAndSecurity;

  /// No description provided for @chat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chat;

  /// No description provided for @syncDraft.
  ///
  /// In zh, this message translates to:
  /// **'同步草稿'**
  String get syncDraft;

  /// No description provided for @syncDraftDesc.
  ///
  /// In zh, this message translates to:
  /// **'在移动端和电脑端之间双向同步聊天草稿'**
  String get syncDraftDesc;

  /// No description provided for @startupAndWindow.
  ///
  /// In zh, this message translates to:
  /// **'启动与窗口'**
  String get startupAndWindow;

  /// No description provided for @closeToExitTitle.
  ///
  /// In zh, this message translates to:
  /// **'点击窗口关闭按钮时退出应用程序'**
  String get closeToExitTitle;

  /// No description provided for @closeToExitDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，点击关闭按钮仅将窗口最小化到系统托盘'**
  String get closeToExitDesc;

  /// No description provided for @minimizeToTaskbarTitle.
  ///
  /// In zh, this message translates to:
  /// **'允许主窗口最小化到任务栏'**
  String get minimizeToTaskbarTitle;

  /// No description provided for @minimizeToTaskbarDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，窗口可以最小化；关闭后，窗口将保持在前台'**
  String get minimizeToTaskbarDesc;

  /// No description provided for @termsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get termsOfService;

  /// No description provided for @userAgreementDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读野火IM软件许可及服务协议'**
  String get userAgreementDesc;

  /// No description provided for @privacyPolicyDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读野火IM隐私政策'**
  String get privacyPolicyDesc;

  /// No description provided for @messageAlerts.
  ///
  /// In zh, this message translates to:
  /// **'消息提示'**
  String get messageAlerts;

  /// No description provided for @receiveNewMessageNotification.
  ///
  /// In zh, this message translates to:
  /// **'接收新消息通知'**
  String get receiveNewMessageNotification;

  /// No description provided for @receiveNewMessageNotificationDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启或关闭新消息到达时的系统声音和横幅通知'**
  String get receiveNewMessageNotificationDesc;

  /// No description provided for @receiveCallNotification.
  ///
  /// In zh, this message translates to:
  /// **'接收语音或视频来电通知'**
  String get receiveCallNotification;

  /// No description provided for @receiveCallNotificationDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启或关闭新呼叫到达时的来电窗口提醒'**
  String get receiveCallNotificationDesc;

  /// No description provided for @showNotificationDetail.
  ///
  /// In zh, this message translates to:
  /// **'通知显示消息详情'**
  String get showNotificationDetail;

  /// No description provided for @showNotificationDetailDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后通知显示消息的发件人和预览内容，关闭后只显示“收到一条新消息”'**
  String get showNotificationDetailDesc;

  /// No description provided for @noDisturb.
  ///
  /// In zh, this message translates to:
  /// **'免打扰'**
  String get noDisturb;

  /// No description provided for @noDisturbPeriod.
  ///
  /// In zh, this message translates to:
  /// **'当前免打扰时间段: {period}'**
  String noDisturbPeriod(Object period);

  /// No description provided for @noDisturbDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后在特定时间段内接收消息不发出声音或振动提醒'**
  String get noDisturbDesc;

  /// No description provided for @simplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @interfaceAppearance.
  ///
  /// In zh, this message translates to:
  /// **'界面外观'**
  String get interfaceAppearance;

  /// No description provided for @interfaceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get interfaceLanguage;

  /// No description provided for @interfaceLanguageDesc.
  ///
  /// In zh, this message translates to:
  /// **'更改界面语言；重启应用后生效'**
  String get interfaceLanguageDesc;

  /// No description provided for @appearanceTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get appearanceTheme;

  /// No description provided for @appearanceThemeDesc.
  ///
  /// In zh, this message translates to:
  /// **'在深色和浅色主题之间切换，或跟随系统外观'**
  String get appearanceThemeDesc;

  /// No description provided for @fontSizeDesc.
  ///
  /// In zh, this message translates to:
  /// **'调整界面的文字显示大小'**
  String get fontSizeDesc;

  /// No description provided for @setSuccessRestartToApply.
  ///
  /// In zh, this message translates to:
  /// **'设置成功，重启应用后生效'**
  String get setSuccessRestartToApply;

  /// No description provided for @currentLoginAccount.
  ///
  /// In zh, this message translates to:
  /// **'当前登录账号'**
  String get currentLoginAccount;

  /// No description provided for @accountName.
  ///
  /// In zh, this message translates to:
  /// **'账号: {name}'**
  String accountName(Object name);

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @securityAndData.
  ///
  /// In zh, this message translates to:
  /// **'安全与数据'**
  String get securityAndData;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @changePasswordDesc.
  ///
  /// In zh, this message translates to:
  /// **'通过验证旧密码来更改您的登录密码'**
  String get changePasswordDesc;

  /// No description provided for @blacklist.
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get blacklist;

  /// No description provided for @blacklistDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看和管理已屏蔽的联系人'**
  String get blacklistDesc;

  /// No description provided for @backupAndRestoreDesc.
  ///
  /// In zh, this message translates to:
  /// **'备份聊天记录到电脑，或者恢复备份到手机'**
  String get backupAndRestoreDesc;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String aboutVersion(Object version);

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'野火IM是安全、可靠的私有即时通讯平台，易于集成、简单部署维护，方便进行二次开发和与现有系统集成。'**
  String get aboutDescription;

  /// No description provided for @officialWebsite.
  ///
  /// In zh, this message translates to:
  /// **'官方网站'**
  String get officialWebsite;

  /// No description provided for @githubRepo.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库'**
  String get githubRepo;

  /// No description provided for @issueFeedback.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get issueFeedback;

  /// No description provided for @wechatContact.
  ///
  /// In zh, this message translates to:
  /// **'微信: wildfirechat 或 wfchat'**
  String get wechatContact;

  /// No description provided for @openLinkUrl.
  ///
  /// In zh, this message translates to:
  /// **'打开链接: {url}'**
  String openLinkUrl(Object url);

  /// No description provided for @pleaseCompletePasswordFields.
  ///
  /// In zh, this message translates to:
  /// **'请填写所有密码字段'**
  String get pleaseCompletePasswordFields;

  /// No description provided for @passwordNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get passwordNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'新密码必须至少为6个字符'**
  String get passwordTooShort;

  /// No description provided for @oldPassword.
  ///
  /// In zh, this message translates to:
  /// **'旧密码'**
  String get oldPassword;

  /// No description provided for @inputOldPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入旧密码'**
  String get inputOldPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @inputNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入新密码'**
  String get inputNewPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @inputNewPasswordAgain.
  ///
  /// In zh, this message translates to:
  /// **'再次输入新密码'**
  String get inputNewPasswordAgain;

  /// No description provided for @confirmModify.
  ///
  /// In zh, this message translates to:
  /// **'确认修改'**
  String get confirmModify;

  /// No description provided for @removeFromBlacklistConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要将此用户从黑名单中移除吗？'**
  String get removeFromBlacklistConfirm;

  /// No description provided for @removedFromBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'已从黑名单移除'**
  String get removedFromBlacklist;

  /// No description provided for @blacklistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'黑名单为空'**
  String get blacklistEmpty;

  /// No description provided for @blacklistRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get blacklistRemove;

  /// No description provided for @searchOrgMembers.
  ///
  /// In zh, this message translates to:
  /// **'搜索成员'**
  String get searchOrgMembers;

  /// No description provided for @maxSelectCount.
  ///
  /// In zh, this message translates to:
  /// **'最多选择 {count} 人'**
  String maxSelectCount(Object count);

  /// No description provided for @noOrganizationData.
  ///
  /// In zh, this message translates to:
  /// **'暂无组织架构数据'**
  String get noOrganizationData;

  /// No description provided for @orgNoSubOrgOrMembers.
  ///
  /// In zh, this message translates to:
  /// **'该部门暂无下级部门或成员'**
  String get orgNoSubOrgOrMembers;

  /// No description provided for @subDepartments.
  ///
  /// In zh, this message translates to:
  /// **'下级部门'**
  String get subDepartments;

  /// No description provided for @members.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get members;

  /// No description provided for @noMatchedMembers.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的成员'**
  String get noMatchedMembers;

  /// No description provided for @confirmWithCount.
  ///
  /// In zh, this message translates to:
  /// **'确定 ({count}/{max})'**
  String confirmWithCount(Object count, Object max);

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reload;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(Object error);

  /// No description provided for @messageSettings.
  ///
  /// In zh, this message translates to:
  /// **'消息设置'**
  String get messageSettings;

  /// No description provided for @unknownMessageNotImplemented.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持此消息类型，请升级客户端！'**
  String get unknownMessageNotImplemented;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
