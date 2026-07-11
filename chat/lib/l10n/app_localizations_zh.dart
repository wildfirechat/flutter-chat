// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '野火IM';

  @override
  String get appTitle => '野火IM';

  @override
  String get tabChat => '信息';

  @override
  String get tabContact => '联系人';

  @override
  String get tabWork => '工作台';

  @override
  String get tabDiscovery => '发现';

  @override
  String get tabMe => '我的';

  @override
  String get startChat => '发起聊天';

  @override
  String get addFriend => '添加好友';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String scanResult(Object result) {
    return '扫描结果: $result';
  }

  @override
  String scanFail(Object error) {
    return '扫描失败: $error';
  }

  @override
  String invalidQrCode(Object qrcode) {
    return '无效的二维码: $qrcode';
  }

  @override
  String get pcLoginNotSupport => 'PC登录暂未支持';

  @override
  String get pcLoginQrHint => '请使用手机野火IM扫码登录';

  @override
  String get retry => '重试';

  @override
  String get channelNotSupport => '频道功能暂未支持';

  @override
  String get conferenceNotSupport => '会议功能暂未支持';

  @override
  String get groupInfo => '群组信息';

  @override
  String get joinGroup => '加入群聊';

  @override
  String get enterGroup => '进入群聊';

  @override
  String joinFail(Object error) {
    return '加入失败: $error';
  }

  @override
  String get groupName => '群聊名称';

  @override
  String get groupQrCode => '群二维码';

  @override
  String get groupNotice => '群公告';

  @override
  String get clickToCheck => '点击查看';

  @override
  String get groupRemark => '群备注';

  @override
  String get groupManage => '群管理';

  @override
  String get searchChatHistory => '查找聊天内容';

  @override
  String get chatFiles => '会话文件';

  @override
  String get muteNotification => '消息免打扰';

  @override
  String get stickTop => '置顶聊天';

  @override
  String get saveToContact => '保存到通讯录';

  @override
  String get myAliasInGroup => '我在本群的昵称';

  @override
  String get showMemberName => '显示群成员昵称';

  @override
  String get clearChatHistory => '清空聊天记录';

  @override
  String get transferGroup => '转移群组';

  @override
  String get dismissGroup => '解散群组';

  @override
  String get quitGroup => '退出群组';

  @override
  String get clearLocalHistory => '清空本地消息';

  @override
  String get clearRemoteHistory => '清空远程消息';

  @override
  String get clearLocalHistorySuccess => '清理本地消息成功';

  @override
  String get clearRemoteHistorySuccess => '清理远程消息成功';

  @override
  String clearRemoteHistoryFail(Object error) {
    return '清理远程消息失败: $error';
  }

  @override
  String get kickMember => '移除群成员';

  @override
  String get addMember => '添加群成员';

  @override
  String get pickContact => '选择联系人';

  @override
  String get networkError => '网络错误';

  @override
  String get modifyGroupName => '修改群名称';

  @override
  String modifyFail(Object error) {
    return '修改失败: $error';
  }

  @override
  String get onlyOwnerManagerCanModify => '只有群主和管理员可以修改群名称';

  @override
  String get modifyGroupRemark => '修改群备注';

  @override
  String get modifyGroupAlias => '修改群昵称';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get close => '关闭';

  @override
  String get loginConfirm => '登录确认';

  @override
  String get pcLoginConfirmDesc => 'Windows/Mac 电脑登录确认';

  @override
  String get login => '登录';

  @override
  String get cancelLogin => '取消登录';

  @override
  String get loginWithCodeOrPassword => '验证码/密码登录';

  @override
  String get loginCodeTitle => '验证码登录';

  @override
  String get scanned => '已扫码，请在手机上确认登录';

  @override
  String scannedUser(Object user) {
    return '扫描用户：$user';
  }

  @override
  String get loggingIn => '登录中...';

  @override
  String get scanAgain => '重新扫码';

  @override
  String pcStatusError(Object status) {
    return 'PC端状态异常: $status';
  }

  @override
  String get loginSuccess => '登录成功';

  @override
  String loginFail(Object error) {
    return '登录失败: $error';
  }

  @override
  String get loading => '加载中...';

  @override
  String get userInfo => '用户详情';

  @override
  String get sendMsg => '发送消息';

  @override
  String get videoCall => '视频聊天';

  @override
  String get modifyAlias => '修改昵称';

  @override
  String get setAlias => '设置备注';

  @override
  String get moreInfo => '更多信息';

  @override
  String get methodNotImpl => '方法没有实现';

  @override
  String get inputAlias => '请输入备注名';

  @override
  String get inputNickname => '请输入昵称';

  @override
  String get modifySuccess => '修改成功';

  @override
  String get setSuccess => '设置成功';

  @override
  String setFail(Object error) {
    return '设置失败: $error';
  }

  @override
  String get loginPageTitle => '登录';

  @override
  String get loginWithPhoneNumber => '手机号登录';

  @override
  String get phoneNumberHint => '请输入电话号码';

  @override
  String get superCodeHint => '请输入Super code';

  @override
  String get sendCodeSuccess => '验证码发送成功，请在5分钟内进行验证!';

  @override
  String get sendCodeFail => '发送验证码失败!';

  @override
  String get sendCode => '发送验证码';

  @override
  String get newFriend => '新好友';

  @override
  String get favGroup => '收藏群组';

  @override
  String get subscribedChannel => '频道';

  @override
  String get organization => '组织架构';

  @override
  String get mesh => '外部单位';

  @override
  String get domainInfo => '单位信息';

  @override
  String get domainName => '单位名称';

  @override
  String get domainDesc => '单位描述';

  @override
  String get domainEmail => '邮箱';

  @override
  String get domainTel => '电话';

  @override
  String get domainAddress => '地址';

  @override
  String get searchUserNotFound => '没有找到呀，是不是输入的电话号码或者账户不对？';

  @override
  String get searchInCurrentDomain => '在本单位搜索用户';

  @override
  String get searchUserInDomain => '在此单位中查找用户';

  @override
  String loadDomainFail(Object error) {
    return '加载外部单位失败: $error';
  }

  @override
  String get fileTransfer => '文件传输助手';

  @override
  String get joinChatroomFail => '网络错误！加入聊天室失败!';

  @override
  String userLeftChatroom(Object userName) {
    return '$userName 离开了聊天室';
  }

  @override
  String get selectMessage => '请选择消息';

  @override
  String get deleteMessage => '删除消息';

  @override
  String get deleteLocalMessage => '删除本地消息';

  @override
  String get deleteRemoteMessage => '删除远程消息';

  @override
  String deleteRemoteMessageFail(Object error) {
    return '删除远程消息失败: $error';
  }

  @override
  String get forward => '转发';

  @override
  String get forwardOneByOne => '逐条转发';

  @override
  String get forwardCombined => '合并转发';

  @override
  String get sendFail => '发送失败！';

  @override
  String get sent => '已发送';

  @override
  String get chatHistory => '聊天记录';

  @override
  String get allMembers => '所有人';

  @override
  String get messageNotification => '消息通知';

  @override
  String get favorites => '收藏';

  @override
  String get files => '文件';

  @override
  String get accountSafety => '账户安全';

  @override
  String get settings => '设置';

  @override
  String get modifyPortraitSuccess => '修改头像成功';

  @override
  String modifyPortraitFail(Object error) {
    return '修改头像失败: $error';
  }

  @override
  String uploadPortraitFail(Object error) {
    return '上传头像失败: $error';
  }

  @override
  String get takePhoto => '拍摄';

  @override
  String get selectFromAlbum => '从相册选择';

  @override
  String wildfireId(Object id) {
    return '野火号: $id';
  }

  @override
  String get backup_and_restore => '备份与恢复';

  @override
  String get language => '语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get followSystem => '跟随系统';

  @override
  String get privacySettings => '隐私设置';

  @override
  String get theme => '主题';

  @override
  String get currentVersion => '当前版本';

  @override
  String get feedback => '反馈';

  @override
  String get about => '关于野火';

  @override
  String get userAgreement => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get complaints => '投诉';

  @override
  String get diagnostics => '诊断';

  @override
  String get logout => '退出';

  @override
  String get logoutConfirm => '账号将退出';

  @override
  String get albumPicker => '相册';

  @override
  String get emoji => '表情';

  @override
  String get image => '图片';

  @override
  String get accountLabel => '野火号：';

  @override
  String get tips => '提示';

  @override
  String get gotIt => '知道了';

  @override
  String get addFriendSearchHint => '请在左上角搜索框中输入关键词，即可搜索用户，并添加好友';

  @override
  String get friendRequestAccept => '通过';

  @override
  String get friendRequestAccepted => '已通过';

  @override
  String get friendRequestRejected => '已拒绝';

  @override
  String get enterToSendHint => 'Enter 发送,Shift + Enter 换行';

  @override
  String get cameraCapture => '拍摄';

  @override
  String get voiceCall => '通话';

  @override
  String get location => '位置';

  @override
  String get filePicker => '文件';

  @override
  String get businessCard => '名片';

  @override
  String get screenshotTool => '截屏';

  @override
  String get screenshotToolNotAvailable => '截屏工具不可用';

  @override
  String get notSupportedOnCurrentPlatform => '当前平台暂不支持';

  @override
  String get notSupported => '暂不支持';

  @override
  String get singleConversationDetails => '单聊会话详情';

  @override
  String get searchChatContents => '查找聊天内容';

  @override
  String get clearLocalMessages => '清空本地消息';

  @override
  String get clearRemoteMessages => '清空远程消息';

  @override
  String get clearLocalMessagesSuccess => '清理本地消息成功';

  @override
  String get clearRemoteMessagesSuccess => '清理远程消息成功';

  @override
  String clearRemoteMessagesFailed(Object error) {
    return '清理远程消息失败: $error';
  }

  @override
  String get groupConversationDetails => '群会话详情';

  @override
  String get groupMemberList => '成员列表';

  @override
  String get groupNameLabel => '群聊名称';

  @override
  String get groupAnnouncement => '群公告';

  @override
  String get groupRemarkLabel => '群备注';

  @override
  String get groupManagement => '群管理';

  @override
  String get favoriteGroup => '保存到通讯录';

  @override
  String get myAliasInGroupLabel => '我在本群的昵称';

  @override
  String get showGroupMemberNames => '显示群成员昵称';

  @override
  String get quitGroupChat => '退出群组';

  @override
  String get removeGroupMembers => '移除群成员';

  @override
  String get addGroupMembers => '添加群成员';

  @override
  String get selectContacts => '选择联系人';

  @override
  String get modifyGroupNameDialog => '修改群名称';

  @override
  String get modifyGroupRemarkDialog => '修改群备注';

  @override
  String get modifyGroupAliasDialog => '修改群昵称';

  @override
  String get channelDetails => '频道详情';

  @override
  String get unsubscribeChannel => '取消订阅';

  @override
  String modifyFailedWithCode(Object code) {
    return '修改失败: $code';
  }

  @override
  String get chatroom => '聊天室';

  @override
  String get robot => '机器人';

  @override
  String get channels => '频道';

  @override
  String get developmentDocumentation => '开发文档';

  @override
  String get sendTo => '发送给：';

  @override
  String get leaveMessage => '给朋友留言';

  @override
  String get send => '发送';

  @override
  String totalMessages(Object count) {
    return '共$count条消息';
  }

  @override
  String get messageTag => '[消息]';

  @override
  String get open => '打开';

  @override
  String get exit => '退出';

  @override
  String get unsubscribeChannelSuccess => '取消订阅成功';

  @override
  String get pickRemindUser => '选择提醒的人';

  @override
  String get slideUpToCancel => '手指上滑，取消发送';

  @override
  String get releaseToSend => '松开发送';

  @override
  String get holdToTalk => '按下说话';

  @override
  String get noMicrophonePermission => '没有权限，请开启权限!';

  @override
  String recordFailed(Object error) {
    return '录音失败: $error';
  }

  @override
  String get recordTooShort => '录音时间太短';

  @override
  String get releaseToCancel => '松开取消';

  @override
  String get wfcNotificationTitle => '野火IM 消息通知';

  @override
  String get wfcNotificationDesc => 'WildfireChat Message Notification';

  @override
  String get newMessage => '新消息';

  @override
  String get groupChat => '群聊';

  @override
  String get channelNewMessage => '公众号新消息';

  @override
  String get andOthers => ' 等';

  @override
  String get requestAddFriend => '请求添加你为好友';

  @override
  String get friendRequest => '好友申请';

  @override
  String get kickedOffline => '已强制下线';

  @override
  String operateFail(Object error) {
    return '操作失败: $error';
  }

  @override
  String get pcClient => 'PC 客户端';

  @override
  String get webClient => 'Web 客户端';

  @override
  String get miniProgram => '小程序';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get pcOnlineDevices => '已登录设备';

  @override
  String get noPcOnline => '当前没有其他设备登录';

  @override
  String pcOnlineDeviceCount(Object count) {
    return '$count 个设备已登录';
  }

  @override
  String get mobileMute => '手机静音';

  @override
  String get mobileMuteDesc => 'PC端登录时，手机端关闭通知提醒';

  @override
  String get loginTime => '登录时间: ';

  @override
  String get backupConversations => '备份会话中...';

  @override
  String get creatingLocalBackup => '正在创建本地备份...';

  @override
  String get uploadingToPC => '正在上传到PC...';

  @override
  String get restoringConversations => '正在恢复会话...';

  @override
  String get downloadingFiles => '正在下载文件...';

  @override
  String backupFailed(Object error) {
    return '备份失败: $error';
  }

  @override
  String get passwordRequired => '需要密码';

  @override
  String restoreFailed(Object error) {
    return '恢复失败: $error';
  }

  @override
  String get notLoggedIn => '未登录';

  @override
  String get pcResponseTimeout => '等待PC响应超时';

  @override
  String fetchBackupListFailed(Object error) {
    return '获取备份列表失败: $error';
  }

  @override
  String get createLocalBackupFailed => '创建本地备份失败';

  @override
  String uploadFailed(Object error) {
    return '上传失败: $error';
  }

  @override
  String getMetadataFailed(Object error) {
    return '获取元数据失败 $error';
  }

  @override
  String get invalidMetadata => '无效的元数据';

  @override
  String get passwordRequiredForEncrypted => '加密备份需要密码';

  @override
  String get aiRobot => 'AI 机器人';

  @override
  String get audioCallAction => '音频通话';

  @override
  String get videoCallAction => '视频通话';

  @override
  String get pickGroupMember => '选择群成员';

  @override
  String get selectMemberToCall => '请选择一位或者多位成员发起通话';

  @override
  String get callInProgress => '正在通话中，无法再次发起！';

  @override
  String get cannotOpen => '无法打开';

  @override
  String get copy => '复制';

  @override
  String get delete => '删除';

  @override
  String get speechToText => '转文字';

  @override
  String get recall => '撤回';

  @override
  String get reedit => '重新编辑';

  @override
  String get recalledMessageNoContent => '原消息内容已无法获取';

  @override
  String get multiSelect => '多选';

  @override
  String get quote => '引用';

  @override
  String get favoriteAction => '收藏';

  @override
  String get favoriteSuccess => '收藏成功';

  @override
  String favoriteFail(Object error) {
    return '收藏失败: $error';
  }

  @override
  String get audioFileNotAvailable => '音频文件不可用';

  @override
  String get convertFail => '转换失败';

  @override
  String get speechToTextFail => '语音转文字失败';

  @override
  String get speechToTextSuccess => '转文字成功';

  @override
  String speechToTextError(Object error) {
    return '语音转文字异常: $error';
  }

  @override
  String get convertingToText => '转文字中...';

  @override
  String get inviteReasonHint => '请填入申请理由，等待对方同意';

  @override
  String get inputReason => '请输入理由';

  @override
  String get requestSent => '请求已发出！';

  @override
  String networkErrorWithCode(Object code) {
    return '网络错误：$code';
  }

  @override
  String get messageNotExist => '消息不存在';

  @override
  String get loginWithPassword => '密码登录';

  @override
  String get loginWithPhone => '手机号登录';

  @override
  String get inputPassword => '请输入密码';

  @override
  String get inputVerificationCode => '请输入验证码';

  @override
  String get readAndAgree => '我已阅读并同意 ';

  @override
  String get and => ' 和 ';

  @override
  String get agreePolicyFirst => '请先同意用户协议和隐私政策';

  @override
  String get loginWithPhoneCode => '手机验证码登录';

  @override
  String get yesterday => '昨天';

  @override
  String get monthDayFormat => 'MM月dd日';

  @override
  String get yearMonthDayFormat => 'yyyy年MM月dd日';

  @override
  String singleChat(Object target) {
    return '单聊<$target>';
  }

  @override
  String groupChatWithTarget(Object target) {
    return '群聊<$target>';
  }

  @override
  String channelWithTarget(Object target) {
    return '频道<$target>';
  }

  @override
  String chatroomWithTarget(Object target) {
    return '聊天室-<$target>';
  }

  @override
  String get cannotOpenLink => '无法打开链接';

  @override
  String get pickMultipleChats => '选择多个聊天';

  @override
  String get pickOneChat => '选择一个聊天';

  @override
  String get singleSelect => '单选';

  @override
  String get search => '搜索';

  @override
  String get recentChats => '最近聊天';

  @override
  String get contacts => '联系人';

  @override
  String get friends => '好友';

  @override
  String get groups => '群组';

  @override
  String get noSearchResult => '没有搜索到结果';

  @override
  String selectedChatsCount(Object count) {
    return '已选择$count个聊天';
  }

  @override
  String sendWithCount(Object count) {
    return '发送($count)';
  }

  @override
  String get connecting => '连接中...';

  @override
  String get connectionFailed => '连接失败';

  @override
  String pcLoggedIn(Object status) {
    return '$status 已登录';
  }

  @override
  String get deleteConversation => '删除会话';

  @override
  String get untop => '取消置顶';

  @override
  String get top => '置顶';

  @override
  String get clearUnread => '清除未读';

  @override
  String get setUnread => '设为未读';

  @override
  String get draftTag => '[草稿]';

  @override
  String get user => '用户';

  @override
  String get contact => '联系人';

  @override
  String get group => '群组';

  @override
  String get channel => '频道';

  @override
  String get others => '其他';

  @override
  String matchedMessageCount(Object count) {
    return '$count 条消息';
  }

  @override
  String get noFiles => '没有文件';

  @override
  String get unknownFile => '未知文件';

  @override
  String get deleteSuccess => '删除成功';

  @override
  String get deleteFailed => '删除失败';

  @override
  String get imageTag => '[图片]';

  @override
  String get videoTag => '[视频]';

  @override
  String get voiceTag => '[语音]';

  @override
  String get chatHistoryTag => '[聊天记录]';

  @override
  String get fileTag => '[文件]';

  @override
  String get linkTag => '[链接]';

  @override
  String get deleteFavorite => '删除收藏';

  @override
  String get deleteFavoriteConfirm => '确定要删除这条收藏吗？';

  @override
  String get myFavorites => '我的收藏';

  @override
  String get noFavorites => '暂无收藏';

  @override
  String get fileLabel => '文件: ';

  @override
  String get linkLabel => '链接: ';

  @override
  String get favoritesAll => '全部';

  @override
  String get favoritesFile => '文件';

  @override
  String get favoritesMedia => '相册';

  @override
  String get favoritesComposite => '聊天记录';

  @override
  String get unsupportedMessageType => '不支持的消息类型';

  @override
  String get fileRecords => '文件记录';

  @override
  String get allFiles => '所有文件';

  @override
  String get myFiles => '我的文件';

  @override
  String get userFiles => '用户文件';

  @override
  String get searchHint => '输入开始搜索';

  @override
  String get searchPrompt => '输入内容进行搜索';

  @override
  String get readReceiptDetail => '消息回执详情';

  @override
  String readCount(Object count) {
    return '已读 ($count)';
  }

  @override
  String unreadCount(Object count) {
    return '未读 ($count)';
  }

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get addToBlacklist => '加入黑名单';

  @override
  String get removeFromBlacklist => '移出黑名单';

  @override
  String get deleteFriend => '删除好友';

  @override
  String get deleteFriendConfirm => '删除好友后，将同时删除与该好友的聊天记录';

  @override
  String get setStarredFriend => '设为星标朋友';

  @override
  String get cancelStarredFriend => '取消星标朋友';

  @override
  String get friendRequestSent => '好友请求已发送';

  @override
  String get viewAllFriendRequests => '查看全部好友请求';

  @override
  String get remark => '备注名';

  @override
  String get favFriend => '星标好友';

  @override
  String get contactCategory => '联系人';

  @override
  String get starredContact => '星标联系人';

  @override
  String doneWithCount(Object count) {
    return '完成($count)';
  }

  @override
  String get maxUserLimit => '超过最大人数限制';

  @override
  String get selectFromOrganization => '从组织架构选择';

  @override
  String pickedCount(Object count) {
    return '已选择 $count 人';
  }

  @override
  String get pickContactHint => '从左侧勾选联系人';

  @override
  String get collection => '群接龙';

  @override
  String get createCollection => '发起接龙';

  @override
  String get collectionTitle => '接龙标题';

  @override
  String get collectionTitleHint => '请输入接龙标题';

  @override
  String get collectionDesc => '接龙描述';

  @override
  String get collectionDescHint => '请输入接龙描述（选填）';

  @override
  String get collectionTemplate => '参与模板';

  @override
  String get collectionTemplateLabel => '模板: ';

  @override
  String get collectionTemplateHint => '设置参与模板，方便群成员按格式填写';

  @override
  String get collectionTemplateExample => '如：姓名-电话';

  @override
  String get expireSetting => '过期设置';

  @override
  String get noExpire => '无限期';

  @override
  String get setExpire => '设置过期时间';

  @override
  String get expireDate => '过期日期';

  @override
  String get expireTime => '过期时间';

  @override
  String get pleaseSelect => '请选择';

  @override
  String get expireTimeInvalid => '过期时间必须大于当前时间';

  @override
  String get collectionTag => '群接龙';

  @override
  String get collectionPeopleCount => '人';

  @override
  String get collectionStatusActive => '进行中';

  @override
  String get collectionStatusEnded => '已结束';

  @override
  String get collectionStatusCancelled => '已取消';

  @override
  String get collectionJoinAction => '参与接龙';

  @override
  String get collectionEmptyHint => '暂无参与，快来抢沙发吧~';

  @override
  String collectionMoreParticipants(Object count) {
    return '等$count人参与';
  }

  @override
  String get collectionClickToView => '点击查看详情';

  @override
  String get collectionDetail => '接龙详情';

  @override
  String get collectionCreator => '发起者';

  @override
  String get collectionCreatorSuffix => '发起的接龙';

  @override
  String get collectionJoinHint => '请输入参与内容';

  @override
  String get submit => '提交';

  @override
  String get done => '完成';

  @override
  String get confirmDeleteEntry => '确定要删除你的参与记录吗？';

  @override
  String get collectionServiceNotConfigured => '接龙服务未配置';

  @override
  String get collectionLoadFailed => '加载接龙详情失败';

  @override
  String get collectionJoinSuccess => '参与成功';

  @override
  String get collectionJoinFailed => '参与失败';

  @override
  String get collectionUpdateSuccess => '更新成功';

  @override
  String get collectionUpdateFailed => '更新失败';

  @override
  String get collectionDeleteSuccess => '删除成功';

  @override
  String get collectionNotInGroup => '你已不在该群组中';

  @override
  String get collectionCreateSuccess => '接龙创建成功';

  @override
  String get collectionCreateFailed => '创建接龙失败';

  @override
  String get collectionEndTime => '截止时间';

  @override
  String get collectionNoEndTime => '无截止时间';

  @override
  String get poll => '群投票';

  @override
  String get createPoll => '发起投票';

  @override
  String get createPollSubtitle => '创建一个新的群投票';

  @override
  String get myPollsSubtitle => '查看我发起的投票';

  @override
  String get pollEmptyList => '暂无投票记录';

  @override
  String get pollHasVoted => '已投票';

  @override
  String get pollDeleteConfirm => '确定要删除这个投票吗？';

  @override
  String get myPolls => '我的投票';

  @override
  String get pollTitleHint => '请输入投票标题';

  @override
  String get pollDescHint => '请输入投票描述（选填）';

  @override
  String get pollOption => '选项';

  @override
  String get pollAddOption => '添加选项';

  @override
  String get pollType => '投票类型';

  @override
  String get pollSingleChoice => '单选';

  @override
  String get pollMultiChoice => '多选';

  @override
  String get pollMaxSelect => '最多选几项';

  @override
  String get pollOptions => '项';

  @override
  String get pollAnonymousVote => '匿名投票';

  @override
  String get pollAnonymous => '匿名';

  @override
  String get pollShowResult => '始终显示结果';

  @override
  String get pollEndTime => '截止时间';

  @override
  String get pollNoEndTime => '无截止时间';

  @override
  String pollMaxOptionsLimit(Object count) {
    return '最多只能添加$count个选项';
  }

  @override
  String pollMinOptionsRequired(Object count) {
    return '至少需要$count个选项';
  }

  @override
  String get pollSelectOption => '请选择至少一个选项';

  @override
  String get pollSubmitVote => '提交投票';

  @override
  String get pollVotesCount => '票';

  @override
  String get pollPeopleCount => '人参与';

  @override
  String get pollStatusActive => '进行中';

  @override
  String get pollStatusEnded => '已结束';

  @override
  String get pollStatusCancelled => '已取消';

  @override
  String get pollJoinAction => '参与投票';

  @override
  String get pollViewResult => '查看结果';

  @override
  String get pollCreatorSuffix => '发起的投票';

  @override
  String get pollTotalVotes => '总票数';

  @override
  String get pollVotes => '票';

  @override
  String get pollDetail => '投票详情';

  @override
  String get pollLoadFailed => '加载投票详情失败';

  @override
  String get pollServiceNotConfigured => '投票服务未配置';

  @override
  String get pollVoteSuccess => '投票成功';

  @override
  String get pollVoteFailed => '投票失败';

  @override
  String get pollCloseConfirm => '确定要结束这个投票吗？结束后将无法继续投票';

  @override
  String get pollCloseSuccess => '投票已结束';

  @override
  String get pollCloseFailed => '结束投票失败';

  @override
  String get pollCreateSuccess => '投票创建成功';

  @override
  String get pollCreateFailed => '创建投票失败';

  @override
  String pollMaxSelectLimit(Object count) {
    return '最多只能选择$count个选项';
  }

  @override
  String get pollClose => '结束投票';

  @override
  String get pollDelete => '删除投票';

  @override
  String get pollExport => '导出明细';

  @override
  String get pollNamed => '实名';

  @override
  String pollVoterCount(Object count) {
    return '$count人参与';
  }

  @override
  String get pollAlreadyVoted => '已投票';

  @override
  String get pollOptionsTitle => '投票选项';

  @override
  String pollSelectedCount(Object count, Object max) {
    return '已选$count/$max';
  }

  @override
  String get pollDeleteSuccess => '投票已删除';

  @override
  String get pollDeleteFailed => '删除投票失败';

  @override
  String get pollExportFailed => '导出失败';

  @override
  String get pollNoVoterDetails => '暂无投票明细';

  @override
  String get pollShareDetails => '投票明细';

  @override
  String get pollCsvOption => '选项';

  @override
  String get pollCsvUser => '用户';

  @override
  String get pollCsvTime => '时间';

  @override
  String get pollDetailsSuffix => '投票明细';

  @override
  String get pollDefaultFileName => '投票';

  @override
  String pollCreatorFormat(Object creatorName) {
    return '由$creatorName发起';
  }

  @override
  String pollDaysLeft(Object count) {
    return '还剩$count天';
  }

  @override
  String pollHoursLeft(Object count) {
    return '还剩$count小时';
  }

  @override
  String pollMinutesLeft(Object count) {
    return '还剩$count分钟';
  }

  @override
  String get pollNoDeadline => '无截止时间';

  @override
  String get publish => '发布';

  @override
  String get pickFriendsToStartChat => '请选择一位或者多位好友发起聊天';

  @override
  String get creatingGroup => '群组创建中...';

  @override
  String get createGroupChat => '创建群聊';

  @override
  String get createAndSend => '创建并发送';

  @override
  String get forwardSendSeparately => '分别发送给';

  @override
  String get forwardSendMerged => '合并发送给';

  @override
  String get pickTargetsFromLeft => '请在左侧选择联系人或群聊';

  @override
  String selectedContactsCount(Object count) {
    return '已选择$count个联系人';
  }

  @override
  String get pickContactsToCreateGroup => '请选择群成员';

  @override
  String createGroupFail(Object error) {
    return '创建失败：$error';
  }

  @override
  String groupNameEtc(Object names) {
    return '$names等';
  }

  @override
  String get audioVideoCall => '音视频通话';

  @override
  String get callOngoingClickRestore => '通话中 - 点击恢复';

  @override
  String get sendFile => '发送文件';

  @override
  String confirmSendFile(Object fileName) {
    return '确定要发送 \"$fileName\" 吗？';
  }

  @override
  String get desktopOnly => '当前界面仅支持桌面端';

  @override
  String sendCodeFailWithError(Object error) {
    return '发送验证码失败: $error';
  }

  @override
  String get showWindow => '显示窗口';

  @override
  String trayUnreadTooltip(Object count) {
    return '野火IM $count 条未读消息';
  }

  @override
  String get previousImage => '上一张 (←)';

  @override
  String get nextImage => '下一张 (→)';

  @override
  String get rotateLeft => '向左旋转';

  @override
  String get rotateRight => '向右旋转';

  @override
  String get saveAs => '另存为...';

  @override
  String get saveFile => '保存文件';

  @override
  String get saveSuccess => '保存成功';

  @override
  String get saveFailSourceMissing => '保存失败: 找不到源文件或链接';

  @override
  String saveFail(Object error) {
    return '保存失败: $error';
  }

  @override
  String get callStatusEnded => '通话结束';

  @override
  String get callStatusCalling => '正在呼叫...';

  @override
  String get callIncomingInvite => '邀请你进行语音通话';

  @override
  String get callStatusConnecting => '连接中...';

  @override
  String get callDecline => '拒绝';

  @override
  String get callAnswer => '接听';

  @override
  String get callAnswerAudio => '语音接听';

  @override
  String get callAnswerVideo => '视频接听';

  @override
  String get callMute => '静音';

  @override
  String get callHangup => '挂断';

  @override
  String get callSwitchCamera => '翻转';

  @override
  String get callSpeaker => '免提';

  @override
  String get callCameraOn => '开启摄像头';

  @override
  String get callCameraOff => '关闭摄像头';

  @override
  String get openFile => '打开文件';

  @override
  String get deleteFileRecordConfirm => '确定要删除这条文件记录吗？';

  @override
  String get fileRecordDeleted => '文件记录已删除';

  @override
  String get deleteFileRecordFailed => '删除文件记录失败';

  @override
  String get searchFiles => '搜索文件';

  @override
  String get fontSize => '字体大小';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeNormal => '标准';

  @override
  String get fontSizeMedium => '中';

  @override
  String get fontSizeLarge => '大';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get fontSizePreviewIncoming => '预览字体大小';

  @override
  String get fontSizePreviewOutgoing => '拖动下方的滑块，可设置字体大小';

  @override
  String get fontSizePreviewHint => '设置后，会话中的消息、联系人列表等都将按此大小显示。';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get chatLinks => '会话链接';

  @override
  String get noLinks => '暂无链接';

  @override
  String get joinGroupRequests => '入群申请';

  @override
  String get noJoinGroupRequests => '暂无入群申请';

  @override
  String get joinGroupReason => '申请理由';

  @override
  String get agree => '同意';

  @override
  String get reject => '拒绝';

  @override
  String get clearJoinGroupRequests => '清空';

  @override
  String get accepted => '已通过';

  @override
  String get rejected => '已拒绝';

  @override
  String get expired => '已过期';

  @override
  String newJoinGroupRequestCount(Object count) {
    return '有$count条新加群申请';
  }

  @override
  String get joinGroupRequestSent => '已发送给管理员，请等待管理员批准';

  @override
  String get sendFailure => '发送失败';

  @override
  String get joinGroupVerificationEnabled => '该群已开启入群验证';

  @override
  String get pleaseInputJoinGroupReason => '请输入入群理由';

  @override
  String requestJoinGroup(Object name) {
    return '$name 请求加入群聊';
  }

  @override
  String inviteJoinGroup(Object inviter, Object member) {
    return '$inviter 邀请 $member 加入群聊';
  }

  @override
  String get deleteJoinGroupRequest => '删除';

  @override
  String get managerSetting => '管理员';

  @override
  String get muteSetting => '禁言设置';

  @override
  String get allowTemporarySession => '允许临时会话';

  @override
  String get joinGroupPermission => '加群权限';

  @override
  String get freeToJoin => '自由加入';

  @override
  String get memberInviteOnly => '仅群成员邀请';

  @override
  String get managerInviteOnly => '仅管理邀请';

  @override
  String get needManagerVerify => '需要管理审批';

  @override
  String get groupVisible => '群可见性';

  @override
  String get searchable => '可被搜索';

  @override
  String get notSearchable => '不可被搜索';

  @override
  String get groupHistoryMessage => '历史消息';

  @override
  String get groupMaxMember => '最大成员数';

  @override
  String get addManager => '添加管理员';

  @override
  String get removeManager => '移除管理员';

  @override
  String get mutedMembers => '禁言成员';

  @override
  String get allowedMembers => '白名单成员';

  @override
  String get addMutedMember => '添加禁言成员';

  @override
  String get addAllowedMember => '添加白名单成员';

  @override
  String get remove => '移除';

  @override
  String get noCandidateForManager => '没有可添加为管理员的成员';

  @override
  String get noCandidateForMute => '没有可选择的成员';

  @override
  String get unmuteSuccess => '已取消禁言';

  @override
  String get unallowSuccess => '已移除白名单';

  @override
  String get removeManagerSuccess => '已移除管理员';

  @override
  String get groupOwner => '群主';

  @override
  String get groupManager => '管理员';

  @override
  String get muteAllMembers => '全员禁言';

  @override
  String get noOtherMembersToTransfer => '群中没有其他成员可转让';

  @override
  String get transferGroupSuccess => '转让群组成功';

  @override
  String get cloudDrive => '云盘';

  @override
  String get pickDestination => '选择目标位置';

  @override
  String get panServiceNotConfigured => '云盘服务未配置';

  @override
  String get loadFailedRetry => '加载失败，请稍后重试';

  @override
  String get noPanSpaces => '没有网盘空间';

  @override
  String panFileCount(Object count) {
    return '$count个文件';
  }

  @override
  String get panGlobalPublicSpace => '全局公共空间';

  @override
  String get panMyPublicSpace => '我的公共空间';

  @override
  String get panMyPrivateSpace => '我的个人空间';

  @override
  String get paste => '粘贴';

  @override
  String get noFilesYet => '暂无文件';

  @override
  String panItemCount(Object count) {
    return '$count项';
  }

  @override
  String get panCannotMoveFolderIntoItself => '不能将文件夹移动到自身';

  @override
  String get panCannotCopyFolderIntoItself => '不能将文件夹复制到自身';

  @override
  String get panGetDownloadUrlFailed => '获取下载链接失败';

  @override
  String get uploading => '上传中...';

  @override
  String get cancelUpload => '取消上传';

  @override
  String get uploadSuccess => '上传成功';

  @override
  String get uploadCancelled => '上传已取消';

  @override
  String get uploadFail => '上传失败';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get createSuccess => '创建成功';

  @override
  String get createFail => '创建失败';

  @override
  String get rename => '重命名';

  @override
  String get newName => '新名称';

  @override
  String get renameSuccess => '重命名成功';

  @override
  String get renameFail => '重命名失败';

  @override
  String get panNoSpaceToSave => '没有可转存的空间';

  @override
  String get panLoadSpacesFailed => '加载空间失败';

  @override
  String get panDuplicate => '转存';

  @override
  String get panDuplicateSuccess => '转存成功';

  @override
  String get panDuplicateFail => '转存失败';

  @override
  String get panCannotMoveToSameLocation => '不能将文件移动到原位置';

  @override
  String get moveSuccess => '移动成功';

  @override
  String get moveFail => '移动失败';

  @override
  String get panCannotCopyToSameLocation => '不能将文件复制到原位置';

  @override
  String get copySuccess => '复制成功';

  @override
  String get copyFail => '复制失败';

  @override
  String deleteFileConfirm(Object name) {
    return '确认要删除“$name”吗？';
  }

  @override
  String get download => '下载';

  @override
  String get downloadOrOpen => '下载/打开';

  @override
  String get share => '分享';

  @override
  String get move => '移动';

  @override
  String get general => '通用';

  @override
  String get appearanceAndTheme => '外观与主题';

  @override
  String get notifications => '通知';

  @override
  String get accountAndSecurity => '账号与安全';

  @override
  String get chat => '聊天';

  @override
  String get syncDraft => '同步草稿';

  @override
  String get syncDraftDesc => '在移动端和电脑端之间双向同步聊天草稿';

  @override
  String get startupAndWindow => '启动与窗口';

  @override
  String get closeToExitTitle => '点击窗口关闭按钮时退出应用程序';

  @override
  String get closeToExitDesc => '关闭后，点击关闭按钮仅将窗口最小化到系统托盘';

  @override
  String get minimizeToTaskbarTitle => '允许主窗口最小化到任务栏';

  @override
  String get minimizeToTaskbarDesc => '开启后，窗口可以最小化；关闭后，窗口将保持在前台';

  @override
  String get termsOfService => '服务条款';

  @override
  String get userAgreementDesc => '阅读野火IM软件许可及服务协议';

  @override
  String get privacyPolicyDesc => '阅读野火IM隐私政策';

  @override
  String get messageAlerts => '消息提示';

  @override
  String get receiveNewMessageNotification => '接收新消息通知';

  @override
  String get receiveNewMessageNotificationDesc => '开启或关闭新消息到达时的系统声音和横幅通知';

  @override
  String get receiveCallNotification => '接收语音或视频来电通知';

  @override
  String get receiveCallNotificationDesc => '开启或关闭新呼叫到达时的来电窗口提醒';

  @override
  String get showNotificationDetail => '通知显示消息详情';

  @override
  String get showNotificationDetailDesc => '开启后通知显示消息的发件人和预览内容，关闭后只显示“收到一条新消息”';

  @override
  String get noDisturb => '免打扰';

  @override
  String noDisturbPeriod(Object period) {
    return '当前免打扰时间段: $period';
  }

  @override
  String get noDisturbDesc => '开启后在特定时间段内接收消息不发出声音或振动提醒';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get interfaceAppearance => '界面外观';

  @override
  String get interfaceLanguage => '界面语言';

  @override
  String get interfaceLanguageDesc => '更改界面语言；重启应用后生效';

  @override
  String get appearanceTheme => '主题';

  @override
  String get appearanceThemeDesc => '在深色和浅色主题之间切换，或跟随系统外观';

  @override
  String get fontSizeDesc => '调整界面的文字显示大小';

  @override
  String get setSuccessRestartToApply => '设置成功，重启应用后生效';

  @override
  String get currentLoginAccount => '当前登录账号';

  @override
  String accountName(Object name) {
    return '账号: $name';
  }

  @override
  String get signOut => '退出登录';

  @override
  String get securityAndData => '安全与数据';

  @override
  String get changePassword => '修改密码';

  @override
  String get changePasswordDesc => '通过验证旧密码来更改您的登录密码';

  @override
  String get blacklist => '黑名单';

  @override
  String get blacklistDesc => '查看和管理已屏蔽的联系人';

  @override
  String get backupAndRestoreDesc => '备份聊天记录到电脑，或者恢复备份到手机';

  @override
  String aboutVersion(Object version) {
    return '版本 $version';
  }

  @override
  String get aboutDescription =>
      '野火IM是安全、可靠的私有即时通讯平台，易于集成、简单部署维护，方便进行二次开发和与现有系统集成。';

  @override
  String get officialWebsite => '官方网站';

  @override
  String get githubRepo => 'GitHub 仓库';

  @override
  String get issueFeedback => '问题反馈';

  @override
  String get wechatContact => '微信: wildfirechat 或 wfchat';

  @override
  String openLinkUrl(Object url) {
    return '打开链接: $url';
  }

  @override
  String get pleaseCompletePasswordFields => '请填写所有密码字段';

  @override
  String get passwordNotMatch => '两次输入的密码不一致';

  @override
  String get passwordTooShort => '新密码必须至少为6个字符';

  @override
  String get oldPassword => '旧密码';

  @override
  String get inputOldPassword => '输入旧密码';

  @override
  String get newPassword => '新密码';

  @override
  String get inputNewPassword => '输入新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get inputNewPasswordAgain => '再次输入新密码';

  @override
  String get confirmModify => '确认修改';

  @override
  String get removeFromBlacklistConfirm => '确定要将此用户从黑名单中移除吗？';

  @override
  String get removedFromBlacklist => '已从黑名单移除';

  @override
  String get blacklistEmpty => '黑名单为空';

  @override
  String get blacklistRemove => '移除';

  @override
  String get searchOrgMembers => '搜索成员';

  @override
  String maxSelectCount(Object count) {
    return '最多选择 $count 人';
  }

  @override
  String maxImageSelectLimit(Object count) {
    return '最多选择 $count 张图片';
  }

  @override
  String get albumPermissionDenied => '无法访问相册，请在系统设置中授予照片访问权限';

  @override
  String get noOrganizationData => '暂无组织架构数据';

  @override
  String get orgNoSubOrgOrMembers => '该部门暂无下级部门或成员';

  @override
  String get subDepartments => '下级部门';

  @override
  String get members => '成员';

  @override
  String get noMatchedMembers => '未找到匹配的成员';

  @override
  String confirmWithCount(Object count, Object max) {
    return '确定 ($count/$max)';
  }

  @override
  String get reload => '重新加载';

  @override
  String searchFailed(Object error) {
    return '搜索失败: $error';
  }

  @override
  String get messageSettings => '消息设置';

  @override
  String get unknownMessageNotImplemented => '暂不支持此消息类型，请升级客户端！';

  @override
  String get pcOnline => '电脑在线';

  @override
  String get padOnline => '平板在线';

  @override
  String get webOnline => '网页在线';

  @override
  String get microAppOnline => '小程序在线';

  @override
  String get mobileOnline => '手机在线';

  @override
  String get busy => '忙碌';

  @override
  String get away => '离开';

  @override
  String mobileOnlineDaysAgo(Object count) {
    return '$count天前';
  }

  @override
  String mobileOnlineHoursAgo(Object count) {
    return '$count时前';
  }

  @override
  String mobileOnlineMinutesAgo(Object count) {
    return '$count分前';
  }

  @override
  String get mobileOnlineJustNow => '不久前';
}
