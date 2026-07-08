# Flutter-chat vs iOS-chat 功能差异分析报告

> 对比日期: 2026-07-08
> 对比源: `ios-chat` (原生 iOS, 较完善) vs `flutter-chat` (Flutter 跨平台, dev-pc-ffi-av 分支)

---

## 一、项目架构对比

| 维度 | ios-chat (原生) | flutter-chat (Flutter) |
|------|----------------|----------------------|
| 语言 | Swift/ObjC | Dart |
| 项目结构 | xcworkspace + CocoaPods | Flutter multi-module monorepo |
| 核心 SDK | wfclient/WFChatClient (原生封装) | imclient (Dart + FFI) |
| UI 层 | wfuikit/WFChatUIKit (原生 UIKit) | chat/lib (Flutter Widget) |
| 应用层 | wfchat/WildFireChat | chat/ |

---

## 二、iOS 已有、Flutter 缺失的功能模块

### 2.1 云盘/Pan (网盘/文件存储)

**iOS**: `/wfchat/WildFireChat/PanService/` + `/wfuikit/WFChatUIKit/Pan/`
- `WFCUPanFile` - 网盘文件模型
- `WFCUPanFileListViewController` - 网盘文件列表
- `WFCUPanFilePickerViewController` - 网盘文件选择器
- `WFCUPanService` - 网盘服务接口
- `WFCUPanSpace` - 网盘空间信息
- `WFCUPanUploadManager` - 网盘上传管理器
- `WFCUPanViewController` - 网盘主页面
- `PanService` - 应用层网盘服务

**Flutter**: **完全缺失**

**影响**: 用户无法在 Flutter 版本中使用网盘/云存储功能，无法上传、浏览、分享网盘文件。

---

### 2.2 物联网/Things (IoT 设备管理)

**iOS**: `/wfchat/WildFireChat/Things/`
- `Device` - 设备模型
- `DeviceTableViewController` - 设备列表
- `DeviceViewController` - 设备控制页
- `DeviceInfoViewController` - 设备信息页
- `CreateDeviceViewController` - 创建设备
- `WFCCThingsDataContent` - 物联网消息内容 (SDK 层)
- `WFCCThingsLostEventContent` - 设备丢失事件 (SDK 层)

**Flutter**: **完全缺失**

**影响**: 无法在 Flutter 版本中管理物联网设备、接收设备消息。

---

### 2.3 朋友圈/Moments (社交动态)

**iOS**:
- `Moments/WFMomentClient.framework` - 朋友圈客户端 SDK
- `Moments/WFMomentUIKit.framework` - 朋友圈 UI 组件
- `DiscoverMomentsTableViewCell` / `DiscoverMomentsTableViewCell.m` - 发现页朋友圈入口

**Flutter**: `momentclient/` 已有 SDK 但功能极简 (仅 4 个 Dart 文件)
- `pubspec.yaml` 中 `momentclient` 的依赖被**注释掉** (`#  momentclient:`)
- 缺少完整的 UI 层 (发动态、动态列表、评论、点赞等)

**影响**: Flutter 版本目前无法使用朋友圈功能。

---

### 2.4 对讲机/PTT (Push-to-Talk/实时对讲)

**iOS**:
- `/wfchat/WildFireChat/Ptt/` - 应用层 PTT
  - `WFPttChannelListViewController` - 对讲频道列表
  - `WFPttCreateChannelViewController` - 创建对讲频道
  - `WFPttJoinChannelViewController` - 加入对讲频道
- `/wfuikit/WFChatUIKit/Ptt/` - UIKit PTT
  - `WFPttViewController` - 对讲主界面
- SDK 层消息: `WFCCPTTInviteMessageContent`, `WFCCPTTSoundMessageContent`

**Flutter**: **完全缺失**

**影响**: 无法使用实时对讲功能。

---

### 2.5 会议/Conference (多人音视频通话)

**iOS SDK 层**:
- `WFCCConferenceInviteMessageContent` - 会议邀请消息
- `WFCCMultiCallOngoingMessageContent` - 多人通话进行中
- `WFCCJoinCallRequestMessageContent` - 加入通话请求
- `WFCUMultiCallOngoingCell` / `WFCUMultiCallOngoingExpendedCell` - UI 层的多人通话状态 Cell
- `WFCUConferenceInviteCell` - 会议邀请 Cell
- `WFCUCallSummaryCell` - 通话摘要 Cell

**Flutter**: SDK 层的 `imclient` 缺少这些消息类型；UI 层仅有 `voip_call_screen.dart` (双人通话)。

**影响**: 多人音视频会议功能不完整。

---

### 2.6 密聊/Secret Chat (端到端加密聊天)

**iOS SDK 层**:
- `WFCCStartSecretChatMessageContent` - 发起密聊
- `WFCCSecretChatInfo` - 密聊信息模型

**Flutter SDK 层 (`imclient`)**: **完全缺失**

**影响**: 无法使用端到端加密的密聊功能。

---

### 2.7 Markdown 消息渲染

**iOS UIKit**:
- `WFCUMarkdownLabel` - Markdown 文本渲染
- `WFCUMarkdownCell` - Markdown 消息 Cell

**Flutter**: **缺失**。现有的 cell builder 中没有 Markdown 类型。

**影响**: 无法正确渲染 Markdown 格式的消息。

---

### 2.8 图文消息/Articles

**iOS SDK 层**:
- `WFCCArticlesMessageContent` - 图文消息内容
- `WFCUArticlesCell` - 图文消息 Cell (UI 层)

**Flutter SDK 层 (`imclient`)**: **完全缺失**

**影响**: 无法接收和展示图文卡片消息。

---

### 2.9 消息转录/Transcription (语音转文字)

**iOS SDK 层**:
- `WFCCTranscriptionMessageContent` - 语音转文字消息

**Flutter SDK 层 (`imclient`)**: **完全缺失**

**影响**: 无法接收语音消息的转文字内容。

---

### 2.10 会议纪要/Meeting Minutes

**iOS SDK 层**:
- `WFCCMeetingMinutesMessageContent` - 会议纪要消息
- `WFCUMeetingMinutesCell` - 会议纪要 Cell

**Flutter SDK 层 (`imclient`)**: **完全缺失**

**影响**: 无法接收和展示会议纪要消息。

---

### 2.11 销毁账号/Destroy Account

**iOS**:
- `WFCDestroyAccountViewController` - 销毁账号页面

**Flutter**: **完全缺失**

**影响**: 用户无法在应用内销毁账号。

---

### 2.12 Share Extension (分享扩展)

**iOS**: `wfchat/ShareExtension/` (系统级分享扩展 target)
- `SharedConversation` - 分享会话模型
- `SharePredefine` - 分享预定义

**Flutter**: **缺失** (iOS/Android 原生分享扩展需要在平台层实现)

**影响**: 无法从其他 App 分享内容到聊天。

---

### 2.13 Broadcast Extension (录屏直播扩展)

**iOS**: `wfchat/Broadcast/` + `wfchat/BroadcastSetupUI/`

**Flutter**: **缺失** (需要平台层支持)

**影响**: 无法进行屏幕共享直播。

---

### 2.14 CallKit 集成

**iOS**:
- `WFCCallKitManager` - iOS CallKit 管理器 (系统级通话界面)

**Flutter**: **缺失** (iOS 平台缺少 CallKit 集成)

**影响**: iOS 平台 VoIP 通话无法使用系统电话界面。

---

### 2.15 链接消息记录/Link Records

**iOS UIKit**:
- `WFCULinksViewController` - 会话中所有链接列表
- `WFCULinkRecordTableViewCell` - 链接记录 Cell
- `WFCULinkCell` - 链接消息 Cell

**Flutter**: **缺失**。仅有 `link_message_content.dart` SDK 模型，但 UI 层没有专门展示。

---

### 2.16 消息日历搜索

**iOS UIKit**:
- `WFCUCalendarSearchViewController` - 按日期搜索消息

**Flutter**: **缺失**

---

### 2.17 全局搜索增强

**iOS UIKit**:
- `WFCUConversationSearchTableViewController` - 会话内搜索
- `WFCUConversationSearchTableViewCell` - 会话搜索结果 Cell
- `WFCUSearchGroupTableViewCell` - 群组搜索结果
- `WFCUSearchViewController` - 全局搜索
- `WFCUUserMessageListViewController` - 用户消息列表

**Flutter**: 已有基础搜索 (`search/` 目录)，但缺少会话内搜索和群组搜索。

---

### 2.18 黑名单/Black List

**iOS UIKit**:
- `WFCUBlackListViewController` - 黑名单管理

**Flutter**: **缺失**

---

### 2.19 多域/Mesh (多域联合)

**iOS UIKit**:
- `WFCUDomainProfileTableViewController` - 域配置
- `WFCUDomainTableViewController` - 域列表
- SDK: `WFCCDomainInfo` - 域信息模型

**Flutter SDK 层 (`imclient`)**: **缺失**
**Flutter UI 层**: **缺失**

---

### 2.20 最近图片快捷入口

**iOS UIKit**:
- `WFCURecentImagesFloatView` - 聊天页浮动最近图片按钮

**Flutter**: **缺失**

---

### 2.21 群接龙/Group Join Request 管理

**iOS**:
- `WFCCJoinGroupRequest` - SDK 模型
- `WFCUJoinGroupRequestViewController` - 群加入申请管理
- `WFCUJoinGroupRequestTableViewCell` - 申请列表 Cell

**Flutter SDK 层 (`imclient`)**: **缺失** `JoinGroupRequest` 模型

---

### 2.22 推送平台集成 (个推/Getui)

**iOS**: `/wfchat/WildFireChat/Getui/` - 个推 SDK 集成

**Flutter**: **缺失**

---

## 三、消息类型差异 (SDK 层)

以下消息类型在 iOS `WFChatClient` 中存在，但在 Flutter `imclient` 中缺失:

| iOS SDK 消息类型 | 说明 |
|-----------------|------|
| `WFCCArticlesMessageContent` | 图文卡片消息 |
| `WFCCConferenceInviteMessageContent` | 会议邀请 |
| `WFCCEnterChannelChatMessageContent` | 进入频道聊天 |
| `WFCCLeaveChannelChatMessageContent` | 离开频道聊天 |
| `WFCCGroupRejectJoinNotificationContent` | 拒绝加群通知 |
| `WFCCGroupSettingsNotificationContent` | 群设置变更通知 |
| `WFCCJoinCallRequestMessageContent` | 加入通话请求 |
| `WFCCKickoffGroupMemberVisibleNotificationContent` | 移出群成员可见通知 |
| `WFCCMarkUnreadMessageContent` | 标记未读 |
| `WFCCMeetingMinutesMessageContent` | 会议纪要 |
| `WFCCModifyGroupAliasNotificationContent` | 修改群别名通知 |
| `WFCCModifyGroupExtraNotificationContent` | 修改群扩展信息通知 |
| `WFCCModifyGroupMemberExtraNotificationContent` | 修改群成员扩展信息 |
| `WFCCMultiCallOngoingMessageContent` | 多人通话进行中 |
| `WFCCNotDeliveredMessageContent` | 未送达消息 |
| `WFCCPTTInviteMessageContent` | PTT 邀请 |
| `WFCCPTTSoundMessageContent` | PTT 语音 |
| `WFCCPollResultMessageContent` | 投票结果消息 |
| `WFCCQuitGroupVisibleNotificationContent` | 退群可见通知 |
| `WFCCRawMessageContent` | 原始消息 |
| `WFCCRichNotificationMessageContent` | 富通知消息 |
| `WFCCStartSecretChatMessageContent` | 发起密聊 |
| `WFCCThingsDataContent` | 物联网数据 |
| `WFCCThingsLostEventContent` | 物联网设备丢失事件 |
| `WFCCTranscriptionMessageContent` | 语音转文字 |
| `WFCCChannelMenuEventMessageContent` | 频道菜单事件 |

---

## 四、应用层功能差异

| 功能 | iOS 原生 | Flutter |
|------|---------|---------|
| 备份/恢复 | `Backup/WFCCMessageBackupManager` (SDK) + 多个 VC | `backup/` 目录 (基本完整) |
| 收藏/Favorite | `Favorite/` (10+ Cell 类型) | `settings/favorite_list_screen.dart` (仅列表) |
| 隐私设置 | `Privacy/`, `Me/WFCPrivacyTableViewController` | `settings/general_settings.dart` (基础) |
| 字体大小 | `Me/WFCFontSizeViewController` | **缺失** |
| 主题切换 | `Me/WFCThemeTableViewController` | **部分** (通过 Provider 切换) |
| 语言切换 | `WFCLanguageManager` | `l10n/` 目录 + `locale_view_model` |
| 诊断 | `Me/WFCDiagnoseViewController` | **缺失** |
| 修改密码 | `Me/WFCChangePasswordViewController` / `WFCResetPasswordViewController` | **缺失** |
| 水印 | `Vendor/TYHWaterMark/TYHWaterMark` | `widget/watermark_overlay.dart` (已有) |
| 二维码处理 | `QrCodeHelper` | `scanner/qr_scanner_screen.dart` (仅扫描) |
| 拨号盘 | `WFCUDialPadViewController` | **缺失** |
| Channel 频道 | `Channel/` (4 个 VC) | `channel/` (3 个文件，基本对应) |

---

## 五、PC 桌面适配 (Flutter 独有)

`flutter-chat` 的 `chat/lib/pc/` 目录包含了完整的 PC 桌面适配，这在 iOS 原生版本中没有对应功能:

- 三栏式桌面 Shell (`pc_home.dart`)
- 系统托盘管理 (`pc_tray_manager.dart`)
- 桌面窗口管理 (`pc_window_manager.dart`)
- PC 专用 UI 组件 (hover, dialog, popover, side sheet)
- PC 登录 (二维码扫码登录)
- PC 搜索视图、联系人列表、发现页等

---

## 六、Flutter 项目内部差异

### 6.1 avenginekit vs flutter-avenginekit

两个模块代码结构**几乎完全相同** (各 17 个 Dart 文件)，但依赖不同:
- `avenginekit/`: 依赖 `flutter_webrtc: ^1.5.2` (pub.dev 标准版)
- `flutter-avenginekit/`: 依赖 `flutter_webrtc` 本地路径版 (`path: ../../fluttertpc_flutter_webrtc/`)

`chat/pubspec.yaml` 引用的是 `avenginekit/`，`flutter-avenginekit` 尚未启用。

### 6.2 rtckit

`rtckit/` 目录存在但仅包含构建配置文件，**没有任何 Dart 源代码**，是一个空架子。

---

## 七、总结

### 优先级评估

**P0 (核心缺失，影响基础功能)**:
1. 云盘/Pan - 文件存储功能
2. 朋友圈/Moments - 社交动态

**P1 (重要缺失，影响用户体验)**:
3. 多人会议/Conference - 多人音视频
4. 对讲机/PTT - 实时语音对讲
5. 图文消息/Articles - 富文本卡片消息
6. 语音转文字/Transcription
7. 会议纪要/Meeting Minutes

**P2 (功能增强)**:
8. 密聊/Secret Chat - 端到端加密
9. 物联网/Things - IoT 设备管理
10. Markdown 消息渲染
11. 消息日历搜索
12. 黑名单管理
13. Share Extension
14. CallKit 集成
15. 链接消息记录
16. 最近图片快捷入口
17. 字体大小设置
18. 诊断功能
19. 修改密码
20. 拨号盘

**P3 (SDK 消息类型补充)**:
21. 31 种缺失的消息类型需在 `imclient/lib/message/` 中补充完善
