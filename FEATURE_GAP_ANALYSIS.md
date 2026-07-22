# Flutter-chat vs iOS-chat 功能差异分析报告

> 对比日期: 2026-07-08
> 对比源: `ios-chat` (原生 iOS, 较完善) vs `flutter-chat` (Flutter 跨平台, dev-pc-ffi-av 分支)
> 更新说明 (2026-07-22): 移除已实现的功能条目 —— 朋友圈/Moments（移动端入口 + PC 独立窗口 + momentkit 全套 UI）、多人会议流程（发现页入口、创建/加入/邀请、PC 会议窗口）、消息日历搜索、全局/会话内搜索增强（分类标签/按日期/按媒体/PC 搜索窗口）、多域 Mesh（DomainInfo 模型 + Dart API + mesh UI）、CallKit（iOS 已集成）、字体大小设置、主题切换；移除明确不实现的条目 —— 物联网/Things 设备管理。

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

### 2.1 对讲机/PTT (Push-to-Talk/实时对讲)

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

### 2.2 密聊/Secret Chat (端到端加密聊天)

**iOS SDK 层**:
- `WFCCStartSecretChatMessageContent` - 发起密聊
- `WFCCSecretChatInfo` - 密聊信息模型

**Flutter**: **部分实现**。`imclient` 已包含 `StartSecretChatMessageContent` 和 FFI 绑定(`createSecretChat`、`destroySecretChat`、`getSecretChatInfo` 等),但缺少接受密聊、销毁密聊、密聊消息、焚毁消息等消息内容类型,`chat` 层也没有密聊 UI（仅 `constants.dart` 有 `kUserSettingDisableSecretChat` 设置常量）。

**影响**: 无法使用端到端加密的密聊功能。

---

### 2.3 会议纪要/Meeting Minutes

**iOS SDK 层**:
- `WFCCMeetingMinutesMessageContent` - 会议纪要消息
- `WFCUMeetingMinutesCell` - 会议纪要 Cell

**Flutter SDK 层 (`imclient`)**: 已包含 `MeetingMinutesMessageContent` 消息类型（type 25,已注册）。
**Flutter UI 层 (`chat`)**: **缺失**,`cell_builder/` 下没有会议纪要 Cell,会话中落到 unknown 展示。

**影响**: 无法接收和展示会议纪要消息。

---

### 2.4 会议邀请/多人通话消息 Cell

> 多人会议功能本身已在 Flutter 侧完整实现（发现页入口、`chat/lib/call/conference/` 全套界面、会议二维码 deep-link、PC 独立会议窗口），仅剩消息展示差距。

**iOS UIKit**:
- `WFCUConferenceInviteCell` - 会议邀请卡片 Cell（带加入按钮）
- `WFCUMultiCallOngoingCell` / `WFCUMultiCallOngoingExpendedCell` - 多人通话进行中 Cell

**Flutter**: **缺失**。`ConferenceInviteMessageContent`、`MultiCallOngoingMessageContent` 在会话中仅按通用通知（digest 纯文本）展示,没有卡片式 Cell 和加入入口。

---

### 2.5 销毁账号/Destroy Account

**iOS**:
- `WFCDestroyAccountViewController` - 销毁账号页面

**Flutter**: **缺失**

**影响**: 用户无法在应用内销毁账号。

---

### 2.6 Share Extension - Android 分享接收

**iOS**: `chat/ios/ShareExtension/` **已实现**（分享会话选择、预定义文案,见 `SHARE_EXTENSION_GUIDE.md`）。

**Flutter (Android)**: **缺失**,`AndroidManifest.xml` 无 `ACTION_SEND` intent-filter,无法从其他 App 分享内容到聊天。

---

### 2.7 Broadcast Extension (录屏直播扩展)

**iOS**: `wfchat/Broadcast/` + `wfchat/BroadcastSetupUI/`

**Flutter**: **缺失** (需要平台层支持)

**影响**: 无法进行屏幕共享直播。

---

### 2.8 最近图片快捷入口

**iOS UIKit**:
- `WFCURecentImagesFloatView` - 聊天页浮动最近图片按钮

**Flutter**: **缺失**

---

### 2.9 推送平台集成 (个推/Getui)

**iOS**: `/wfchat/WildFireChat/Getui/` - 个推 SDK 集成

**Flutter**: **缺失**

---

## 三、消息类型差异 (SDK 层)

经过核对,`imclient/lib/message/` 中已实现并注册的消息类型包括:图文卡片、会议邀请、进入/离开频道聊天、群通知系列、加入通话请求、标记未读、会议纪要、多人通话进行中、未送达消息、PTT 邀请/语音、投票结果、富通知、发起密聊、物联网数据/设备丢失、语音转文字、频道菜单事件等。

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
| 收藏/Favorite | `Favorite/` (10+ Cell 类型) | **部分实现** | 已支持消息收藏、收藏列表、删除、PC 分类视图、图片/视频预览;文件、链接等类型的打开操作仍为占位（仅 toast） |
| 隐私设置 | `Privacy/`, `Me/WFCPrivacyTableViewController` | **部分** | `settings/general_settings.dart` 基础 |
| 诊断 | `Me/WFCDiagnoseViewController` | **缺失** | 设置页仅有一个未实现的占位入口 |
| 拨号盘 (DTMF) | `WFCUDialPadViewController` | **缺失** | 通话界面均无拨号键盘 |

> 已移除的条目: 备份/恢复、修改密码、水印、二维码扫描、Channel 频道、语言切换、字体大小、主题切换 —— 这些功能在 Flutter 侧已有对应实现。

---

## 五、PC 桌面适配 (Flutter 独有)

`flutter-chat` 的 `chat/lib/pc/` 目录包含了完整的 PC 桌面适配,这在 iOS 原生版本中没有对应功能:

- 三栏式桌面 Shell (`pc_home.dart`)
- 系统托盘管理 (`pc_tray_manager.dart`)
- 桌面窗口管理 (`pc_window_manager.dart`)
- 多窗口公共层 (`pc/multi_window/`) 与四类独立子窗口:通话、媒体预览、朋友圈、会话搜索
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

**P1 (重要缺失,影响用户体验)**:
1. 会议纪要/Meeting Minutes Cell - SDK 消息类型已有,缺 UI
2. 会议邀请/多人通话消息 Cell - 会议功能已有,缺卡片式消息展示与加入入口
3. 对讲机/PTT - 实时语音对讲 (SDK 消息类型已有,缺 UI 与引擎集成)
4. 密聊/Secret Chat - 端到端加密 (create 消息类型已有,其余消息类型与 UI 缺失)

**P2 (功能增强)**:
5. 销毁账号
6. Share Extension - Android 分享接收 (iOS 已实现)
7. Broadcast Extension 录屏直播
8. 最近图片快捷入口
9. 收藏的文件/链接类型打开操作 (现为占位)
10. 诊断功能
11. 拨号盘 (DTMF)
12. 推送平台集成 (个推)

**P3 (SDK 消息类型补充)**:
13. `RawMessageContent` 等少量缺失的消息类型需在 `imclient/lib/message/` 中补充
