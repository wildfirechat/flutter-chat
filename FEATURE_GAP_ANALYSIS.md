# Flutter-chat vs iOS-chat 功能差异分析报告

> 对比日期: 2026-07-08
> 对比源: `ios-chat` (原生 iOS, 较完善) vs `flutter-chat` (Flutter 跨平台, dev-pc-ffi-av 分支)
> 更新说明: 本次移除了已在 Flutter 侧实现的功能模块（链接消息记录、入群申请管理）, 并删除了不存在的 Markdown 消息渲染条目; 其余已实现的功能标注为“SDK/协议层已有,UI/应用层待补齐”。

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

> 标注规则:
> - **缺失**: Flutter 侧没有可用功能。
> - **部分实现**: SDK/协议层或核心模型已存在,但缺少用户可感知的 UI 或完整流程。

### 2.1 物联网/Things (IoT 设备管理)

**iOS**: `/wfchat/WildFireChat/Things/`
- `Device` - 设备模型
- `DeviceTableViewController` - 设备列表
- `DeviceViewController` - 设备控制页
- `DeviceInfoViewController` - 设备信息页
- `CreateDeviceViewController` - 创建设备
- `WFCCThingsDataContent` - 物联网消息内容 (SDK 层)
- `WFCCThingsLostEventContent` - 设备丢失事件 (SDK 层)

**Flutter**: **部分实现**。`imclient` 已包含 `ThingsDataContent`、`ThingsLostEventContent` 两种消息内容类型及 `ConversationType.Things`,但应用层没有设备管理 UI、设备模型或设备相关 API。

**影响**: 无法在 Flutter 版本中管理物联网设备、接收设备消息。

---

### 2.2 朋友圈/Moments (社交动态)

**iOS**:
- `Moments/WFMomentClient.framework` - 朋友圈客户端 SDK
- `Moments/WFMomentUIKit.framework` - 朋友圈 UI 组件
- `DiscoverMomentsTableViewCell` / `DiscoverMomentsTableViewCell.m` - 发现页朋友圈入口

**Flutter**: `momentclient/` 已有 Dart SDK 包装层 (`MomentClient`、`Feed`、`Comment` 等),但 `chat/pubspec.yaml` 中 `momentclient` 依赖被**注释掉**,`chat/lib` 中缺少发动态、动态列表、评论、点赞等 UI,发现页也未接入入口。

**影响**: Flutter 版本目前无法使用朋友圈功能。

---

### 2.3 对讲机/PTT (Push-to-Talk/实时对讲)

**iOS**:
- `/wfchat/WildFireChat/Ptt/` - 应用层 PTT
  - `WFPttChannelListViewController` - 对讲频道列表
  - `WFPttCreateChannelViewController` - 创建对讲频道
  - `WFPttJoinChannelViewController` - 加入对讲频道
- `/wfuikit/WFChatUIKit/Ptt/` - UIKit PTT
  - `WFPttViewController` - 对讲主界面
- SDK 层消息: `WFCCPTTInviteMessageContent`, `WFCCPTTSoundMessageContent`

**Flutter**: **部分实现**。`imclient` 已注册 `PttVoiceMessageContent`、`PttInviteMessageContent` 两种消息类型,并定义了相关用户设置常量;但应用层没有对讲频道列表、创建/加入频道 UI、对讲界面,且原生 PTT SDK AAR 依赖未启用。

**影响**: 无法使用实时对讲功能。

---

### 2.4 会议/Conference (多人音视频通话)

**iOS SDK 层**:
- `WFCCConferenceInviteMessageContent` - 会议邀请消息
- `WFCCMultiCallOngoingMessageContent` - 多人通话进行中
- `WFCCJoinCallRequestMessageContent` - 加入通话请求
- `WFCUMultiCallOngoingCell` / `WFCUMultiCallOngoingExpendedCell` - UI 层的多人通话状态 Cell
- `WFCUConferenceInviteCell` - 会议邀请 Cell
- `WFCUCallSummaryCell` - 通话摘要 Cell

**Flutter**: **部分实现**。`imclient` 已包含会议邀请、多人通话进行中、加入通话请求等消息类型,并暴露 `sendConferenceRequest` 等会议信令 API;`chat` 层也有会议 REST API 封装和会议二维码 deep-link 脚手架。但缺少会议邀请/多人通话 UI,`main.dart` 中 `onJoinConference` 仍为 TODO,仅支持双人通话 (`voip_call_screen.dart`)。

**影响**: 多人音视频会议的用户界面和完整流程缺失。

---

### 2.5 密聊/Secret Chat (端到端加密聊天)

**iOS SDK 层**:
- `WFCCStartSecretChatMessageContent` - 发起密聊
- `WFCCSecretChatInfo` - 密聊信息模型

**Flutter SDK 层 (`imclient`)**: **部分实现**。已包含 `StartSecretChatMessageContent` 和 FFI 绑定(`createSecretChat`、`destroySecretChat`、`getSecretChatInfo` 等),但缺少接受密聊、销毁密聊、密聊消息、焚毁消息等消息内容类型,`chat` 层也没有密聊 UI。

**影响**: 无法使用端到端加密的密聊功能。

---

### 2.6 会议纪要/Meeting Minutes

**iOS SDK 层**:
- `WFCCMeetingMinutesMessageContent` - 会议纪要消息
- `WFCUMeetingMinutesCell` - 会议纪要 Cell

**Flutter SDK 层 (`imclient`)**: 已包含 `MeetingMinutesMessageContent` 消息类型。
**Flutter UI 层 (`chat`)**: **缺失**,没有会议纪要 Cell 和展示页面。

**影响**: 无法接收和展示会议纪要消息。

---

### 2.8 销毁账号/Destroy Account

**iOS**:
- `WFCDestroyAccountViewController` - 销毁账号页面

**Flutter**: **缺失**

**影响**: 用户无法在应用内销毁账号。

---

### 2.9 Share Extension (分享扩展)

**iOS**: `wfchat/ShareExtension/` (系统级分享扩展 target)
- `SharedConversation` - 分享会话模型
- `SharePredefine` - 分享预定义

**Flutter**: **缺失** (iOS/Android 原生分享扩展需要在平台层实现)

**影响**: 无法从其他 App 分享内容到聊天。

---

### 2.10 Broadcast Extension (录屏直播扩展)

**iOS**: `wfchat/Broadcast/` + `wfchat/BroadcastSetupUI/`

**Flutter**: **缺失** (需要平台层支持)

**影响**: 无法进行屏幕共享直播。

---

### 2.11 CallKit 集成

**iOS**:
- `WFCCallKitManager` - iOS CallKit 管理器 (系统级通话界面)

**Flutter**: **缺失** (iOS 平台缺少 CallKit 集成,`rtckit/` 仅有构建配置、无 Dart 源码)

**影响**: iOS 平台 VoIP 通话无法使用系统电话界面。

---

### 2.13 消息日历搜索

**iOS UIKit**:
- `WFCUCalendarSearchViewController` - 按日期搜索消息

**Flutter**: **缺失** (FFI 底层虽有 `searchMessageByTypesAndTimes` 绑定,但未封装为 Dart API,也无 UI)

---

### 2.14 全局搜索增强

**iOS UIKit**:
- `WFCUConversationSearchTableViewController` - 会话内搜索
- `WFCUConversationSearchTableViewCell` - 会话搜索结果 Cell
- `WFCUSearchGroupTableViewCell` - 群组搜索结果
- `WFCUSearchViewController` - 全局搜索
- `WFCUUserMessageListViewController` - 用户消息列表

**Flutter**: **部分实现**。全局搜索(`search_portal_delegate.dart`、`search_portal_result_view.dart`)、会话内关键字搜索(`search_conversation_result_view.dart`)、PC 搜索浮层(`pc_search_view.dart`)均已实现。但群组搜索结果独立展示、按日期/日历搜索消息仍缺失。

---

### 2.15 多域/Mesh (多域联合)

**iOS UIKit**:
- `WFCUDomainProfileTableViewController` - 域配置
- `WFCUDomainTableViewController` - 域列表
- SDK: `WFCCDomainInfo` - 域信息模型

**Flutter SDK 层 (`imclient`)**: 仅有少量 FFI 原生绑定(`isMeshEnabled`、`getDomainInfo`、`getRemoteDomains` 等),未暴露 Dart API,也无 `DomainInfo` 模型。
**Flutter UI 层**: **缺失**

---

### 2.16 最近图片快捷入口

**iOS UIKit**:
- `WFCURecentImagesFloatView` - 聊天页浮动最近图片按钮

**Flutter**: **缺失**

---

### 2.18 推送平台集成 (个推/Getui)

**iOS**: `/wfchat/WildFireChat/Getui/` - 个推 SDK 集成

**Flutter**: **缺失**

---

## 三、消息类型差异 (SDK 层)

经过核对,`FEATURE_GAP_ANALYSIS.md` 初稿中列出的大部分 SDK 消息类型已在 `imclient/lib/message/` 中实现并注册,包括:

- 图文卡片 `ArticlesMessageContent`
- 会议邀请 `ConferenceInviteMessageContent`
- 进入/离开频道聊天 `EnterChannelChatMessageContent` / `LeaveChannelChatMessageContent`
- 拒绝加群/群设置变更/移出群成员可见/退群可见等群通知
- 加入通话请求 `JoinCallRequestMessageContent`
- 标记未读 `MarkUnreadSyncMessageContent`
- 会议纪要 `MeetingMinutesMessageContent`
- 修改群别名/群扩展/群成员扩展等通知
- 多人通话进行中 `MultiCallOngoingMessageContent`
- 未送达消息 `NotDeliveredMessageContent`
- PTT 邀请/PTT 语音 `PttInviteMessageContent` / `PttVoiceMessageContent`
- 投票结果 `PollResultMessageContent`
- 富通知 `RichNotificationMessageContent`
- 发起密聊 `StartSecretChatMessageContent`
- 物联网数据/设备丢失事件 `ThingsDataContent` / `ThingsLostEventContent`
- 语音转文字 `TranscriptionMessageContent`
- 频道菜单事件 `ChannelMenuEventMessageContent`

目前仍缺失的消息类型主要有:

| iOS SDK 消息类型 | 说明 |
|-----------------|------|
| `WFCCRawMessageContent` | 原始/二进制消息内容 |
| `WFCCAcceptSecretChatMessageContent` | 接受密聊 |
| `WFCCDestroySecretChatMessageContent` | 销毁密聊 |
| `WFCCSecretChatMessageContent` | 密聊消息 |
| `WFCCBurnMsgReadedMessageContent` | 焚毁消息已读 |
| `WFCCBurnMsgPlayedMessageContent` | 焚毁消息已播放 |

---

## 四、应用层功能差异

| 功能 | iOS 原生 | Flutter | 备注 |
|------|---------|---------|------|
| 收藏/Favorite | `Favorite/` (10+ Cell 类型) | **部分实现** | 已支持消息收藏、收藏列表、删除、PC 分类视图;部分类型(文件、链接等)的打开操作仍为占位 |
| 隐私设置 | `Privacy/`, `Me/WFCPrivacyTableViewController` | **部分** | `settings/general_settings.dart` 基础 |
| 字体大小 | `Me/WFCFontSizeViewController` | **缺失** | |
| 主题切换 | `Me/WFCThemeTableViewController` | **部分** | 通过 Provider 切换 |
| 诊断 | `Me/WFCDiagnoseViewController` | **缺失** | 设置页仅有一个未实现的占位入口 |
| 拨号盘 | `WFCUDialPadViewController` | **缺失** | |

> 已移除的条目: 备份/恢复、修改密码、水印、二维码扫描、Channel 频道、语言切换 —— 这些功能在 Flutter 侧已有对应实现。

---

## 五、PC 桌面适配 (Flutter 独有)

`flutter-chat` 的 `chat/lib/pc/` 目录包含了完整的 PC 桌面适配,这在 iOS 原生版本中没有对应功能:

- 三栏式桌面 Shell (`pc_home.dart`)
- 系统托盘管理 (`pc_tray_manager.dart`)
- 桌面窗口管理 (`pc_window_manager.dart`)
- PC 专用 UI 组件 (hover, dialog, popover, side sheet)
- PC 登录 (二维码扫码登录)
- PC 搜索视图、联系人列表、发现页、文件/收藏入口等

---

## 六、Flutter 项目内部差异

### 6.1 avenginekit vs flutter-avenginekit

两个模块代码结构**几乎完全相同** (各 17 个 Dart 文件),但依赖不同:
- `avenginekit/`: 依赖 `flutter_webrtc: ^1.5.2` (pub.dev 标准版)
- `flutter-avenginekit/`: 依赖 `flutter_webrtc` 本地路径版 (`path: ../../fluttertpc_flutter_webrtc/`)

`chat/pubspec.yaml` 引用的是 `avenginekit/`,`flutter-avenginekit` 尚未启用。

### 6.2 rtckit

`rtckit/` 目录存在但仅包含构建配置文件,**没有任何 Dart 源代码**,是一个空架子。

---

## 七、总结

### 优先级评估

**P0 (核心缺失,影响基础功能)**:
1. 朋友圈/Moments - 社交动态 (SDK 已有,缺 UI 与接入)
2. 多人会议/Conference - 多人音视频 (SDK/信令/API 已有,缺 UI 和完整流程)

**P1 (重要缺失,影响用户体验)**:
3. 对讲机/PTT - 实时语音对讲 (SDK 消息类型已有,缺 UI 与引擎集成)
4. 会议纪要/Meeting Minutes - SDK 消息类型已有,缺 UI
5. 密聊/Secret Chat - 端到端加密 (create 消息类型已有,其余消息类型与 UI 缺失)

**P2 (功能增强)**:
6. 物联网/Things - IoT 设备管理 (SDK 消息类型已有,缺 UI)
7. 消息日历搜索
8. Share Extension
9. CallKit 集成
10. 最近图片快捷入口
11. 字体大小设置
12. 诊断功能
13. 拨号盘

**P3 (SDK 消息类型补充)**:
14. `RawMessageContent` 等少量缺失的消息类型需在 `imclient/lib/message/` 中补充
