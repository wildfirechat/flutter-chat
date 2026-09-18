# 离线推送推进计划（iOS / Android / 鸿蒙）

> 更新：2026-09-18。选型与现状调研已结束，本文只记录**待推进事项**。
> 代码为什么这么写，看代码里的注释；这里只写还要做什么、改哪里、怎么验。

## 0. 现状

| 环节 | 状态 | 待办 |
| --- | --- | --- |
| 服务端 `push_server`（10 个通道） | 代码完备 | 部署 + 后台配凭据，见 §2.1 |
| `im-server` 推送路由 | 代码完备 | 改 `wildfirechat.conf` 三个地址，见 §2.1 |
| imclient 桥接层（三端 `setDeviceToken`） | 已通 | 无 |
| 鸿蒙 platform 上报 | 已修 | 无 |
| Android 厂商模块 `chat/android/push` | 已集成（小米/华为/荣耀/vivo/OPPO/FCM） | **缺凭据**，见 §2.2 |
| Android 运行时通知权限 | 已补（2026-09-18） | 真机确认弹窗 |
| iOS 普通推送 | 代码完备 | 证书 + capability，见 §2.4 |
| 鸿蒙 PushKit 取 token | **未集成** | 见 §2.3，唯一剩余编码任务 |
| 通知点击跳转 / VoIP / 角标 | 未做 | 二期，见 §3 |

**一期目标**：三端杀进程后能收到通知栏消息。点击跳转、角标、VoIP 都不在一期。

### 已定型的选型（不再讨论）

直连厂商通道 + 自建 `push_server`，不引第三方聚合（个推/极光）、不引社区 Flutter 推送插件
（`ym_flutter_push`、`MixPush` 等覆盖更窄且多已停更，均不支持荣耀和鸿蒙 NEXT）。
Android 侧 token 由厂商 SDK 回调后直接调 `ChatManager.Instance().setDeviceToken()`，**不经 Dart**。

---

## 1. 关键路径：凭据申请

代码工作量不大，**申请周期才是瓶颈，建议立刻并行启动**。
客户端凭据决定「能不能拿到 token」，服务端凭据决定「能不能把消息发给厂商」，**两侧都要配**。

| 平台 | 需要申请 | 客户端落点 | push_server 后台 |
| --- | --- | --- | --- |
| 小米 | AppID / AppKey / AppSecret | `push.xiaomi.appId`、`push.xiaomi.appKey` | AppSecret |
| 华为（Android HMS） | AGC 应用 + Push 开通 | `chat/android/app/agconnect-services.json` | client_id / secret |
| 荣耀 | AppID + 后台密钥 | `push.honor.appId` | ClientId / ClientSecret |
| vivo | AppID / AppKey / AppSecret | `push.vivo.appId`、`push.vivo.appKey` | AppID / AppKey / AppSecret |
| OPPO | AppKey / AppSecret / MasterSecret | `push.oppo.appKey`、`push.oppo.appSecret` | AppKey / MasterSecret |
| FCM（海外包） | Firebase 项目 | `chat/android/app/google-services.json` | service account json |
| 鸿蒙 Push Kit | AGC 鸿蒙应用 + Push 开通 + 证书指纹 | 待接入，见 §2.3 | client_id / secret |
| APNs | 推送证书 or p8 key（dev + prod 两套） | 无（代码已完备） | 上传证书 |
| APNs VoIP（二期） | 独立 VoIP 证书 | `USE_CALL_KIT=1` | 上传证书 |

`push.*` 键写在 `chat/android/local.properties`（不入库）。缺失即为空串，对应厂商自行跳过注册，
不影响构建和其他厂商。华为和 FCM 的两个 json 缺失时 gradle 插件不 apply，构建正常、通道不生效。

---

## 2. 一期待推进事项

按依赖顺序，每步有独立验证点。

### 2.1 服务端准备（0 代码）

1. 部署 `push_server`，改 `application.properties` 换 MySQL（默认 H2 只能单节点）
2. 访问 `http://<host>:8086/admin/`，用 `admin`/`admin123` 登录并**立即改密码**
3. 「配置管理」里逐平台填参数、上传证书
4. 改 `im-server` 的 `broker/config/wildfirechat.conf`（424 行附近）三个地址并重启：

```
push.android.server.address  http://<push-server>:8085/android/push
push.ios.server.address      http://<push-server>:8085/ios/push
push.harmony.server.address  http://<push-server>:8085/harmony/push
```

**验证**：admin 后台推送记录页能看到 im-server 打过来的请求。

### 2.2 Android：填凭据（P0）

模块已接好（`WfcApplication.java:54` 调 `PushService.init`），**当前 `local.properties` 里一个
`push.*` 键都没有**，所有 `manifestPlaceholders` 取到空串 → 厂商 SDK 全部跳过注册，
**包括未知机型的兜底通道小米**。现在的表现是「代码通了但一条推送也收不到」。

按 §1 的表填 `chat/android/local.properties`，华为/FCM 放 json 到 `chat/android/app/`。

**验证**：logcat 出现 `push service type <n>` 和 `setDeviceToken <token> <type>`；
`t_user_session._push_type` 与机型匹配；push_server 日志有 `Android push {...}`。

> `PushService.init` 外面包着大 try-catch，**任何厂商 SDK 初始化异常都会被静默吞掉**。
> 日志里什么都没有时，直接在 `init` 里打断点，别猜。

### 2.3 鸿蒙：PushKit 取 token（唯一剩余编码任务）

`chat/ohos/entry/src/main/ets/entryability/EntryAbility.ets` 目前还是 24 行样板，
`oh-package.json5` 里没有任何 push HAR。

1. AGC 上为鸿蒙应用开通 Push Kit，配好证书指纹（否则 `getToken()` 报 `1000900010`）
2. `chat/ohos/entry/src/main/module.json5` 补权限
3. `EntryAbility.ets` 里 `pushService.getToken()`，拿到后调 `setDeviceToken(8, token)`
   - 最简：直接 import imclient HAR，`marsWrapper.ets` 已 export `setDeviceToken`
   - 时机见 §4 的统一约定
4. push_server 后台配鸿蒙通道（`HMPushServiceImpl` 用华为 oauth2 client_id/secret）

**验证**：`t_user_session._token` 有值、`_push_type` == 8；push_server 收到 `/harmony/push`。

### 2.4 iOS：只做配置

代码链路（`AppDelegate.m:220` → `setDeviceToken`）已完整。

1. push_server 后台上传 APNs 证书（或 p8 key）
2. Xcode 打开 Push Notifications capability
3. **确认 `chat/ios/Runner/Runner.entitlements` 的 `aps-environment` 与后台配的证书环境一致** ——
   当前是 `development`，出 TestFlight / release 包必须改 `production`，
   **环境不匹配是静默失败，不报错**
4. 真机装 release/TestFlight 包，杀进程后由另一端发消息

**验证**：`t_user_session._token` 有值、`_push_type` 与证书环境匹配；push_server 日志有 `iOS push {...}`。

### 2.5 Android release 包验证

`chat/android/push/consumer-rules.pro` 按各厂商文档写全了，但**没做过 release 构建实测**。
首次出 release 包时要专门验一次推送，确认 minify/shrinkResources 没把厂商 SDK 打没。

---

## 3. 二期

1. **通知点击跳转**：厂商 SDK 通过 `${applicationId}.main` 拉起 App（intent-filter 已存在于
   `chat/android/app/src/main/AndroidManifest.xml:46`）。需要三处改动：
   `DefaultPushMessageHandler.handleIMPushMessage` 当前是空实现；`MainActivity` 无 intent 解析；
   `chat/lib/wfc_notification_manager.dart` 的 `onNotificationTapped` 只服务本地通知，
   要扩一条远程通知入口再走 `chat/lib/app_navigator.dart`
2. **VoIP 推送**：
   - iOS：`USE_CALL_KIT=1`（`project.pbxproj` 三处）+ VoIP 证书，代码已完备
   - 鸿蒙：`PushMessageAbility` + `voipCall.reportIncomingCall`，hm-chat 有完整参照实现
   - Android：`PushMessageType.VOIP_INVITE/BYE/ANSWER` 走透传
3. **角标**：iOS 靠 push_server 下发 `unReceivedMsg`；Android 各家 API 不同
4. **隐藏推送详情**：`PushMessage.isHiddenDetail` 服务端已支持，需接到设置项

---

## 4. deviceToken 上报时机（统一约定）

三端 SDK 的缓存行为不一致（Android 会缓存重发，鸿蒙直接透传给 native 不缓存），**不要依赖它**。

统一写法：**token 拿到后本地持久化，并在 `ConnectionStatusChangedEvent == Connected` 时补调一次
`setDeviceToken`。**

---

## 5. pushType 契约表（全链路必须一致）

来源 `push_server/.../android/AndroidPushType.java`，客户端对应 `PushService.PushServiceType`。
**不要随意改动编号。**

| 值 | 通道 |
| --- | --- |
| 1 | 小米 |
| 2 | 华为 HMS |
| ~~3~~ | ~~魅族~~（服务端已移除，客户端不集成） |
| 4 | vivo |
| 5 | OPPO |
| 6 | FCM |
| 7 | 个推 |
| 8 | 极光 |
| 9 | 荣耀 |
| 10 | UniPush v2 |

**鸿蒙特例**：传的也是 8，但走独立的 `/harmony/push` endpoint，与 Android 的 8=极光不冲突。

iOS 的 pushType 分开发 / 发布两种，由 SDK 按证书环境上报。

---

## 6. 排查链路（收不到推送时按序走）

1. 确认 App 是**杀进程**状态。退到桌面时 App 仍活着，走的是本地通知，不经推送服务
2. 客户端是否拿到 token 并调了 `setDeviceToken`？Android 看 logcat 的 `setDeviceToken <token> <type>`
3. **`t_user_session` 表的 `_token` / `_push_type` / `_platform` 三个字段** —— 判断客户端上报
   是否成功的第一道锚点。`_platform` 不对会导致 im-server 直接不推
4. 自定义消息必须 `pushContent` 或 `pushData` 至少一个非空，且 `PersistFlag` 必须是存储或存储计数
5. 目标用户 7 日内必须登录过，超过不推
6. 目标用户是否全局静音 / 会话静音？是否有 PC/Web 在线且开了「PC 在线时手机静音」？
7. im-server 日志：`Send push to {}, message from {}`
8. push_server 日志：`Android push {...}` / `iOS push {...}`，核对 token 和 type 与第 3 步一致
9. 到这一步之后就是厂商侧问题了，按厂商文档调
10. Android 用户侧设置也会拦：允许后台运行、允许自启动、允许后台弹界面、允许显示通知

---

## 7. 已知坑

- **`PushService.init` 的大 try-catch 吞掉一切厂商 SDK 异常**，排查时必须打断点（见 §2.2）
- 华为缺 `agconnect-services.json` 时 `AGConnectServicesConfig.fromContext(...)` 会抛异常，
  被上面那个 try-catch 吞掉 → 表现为「什么都没发生」，不是崩溃
- 小米推送必须判主进程（`shouldInitXiaomi`），多进程会重复注册
- FCM 会引入 gms 依赖，国内包体和合规是问题 → 后续按渠道拆 flavor，国内包不放
  `google-services.json` 即可（插件不 apply，通道不生效）
- 厂商探测顺序：华为 → 荣耀 → vivo → OPPO → 小米 → FCM → **兜底小米**。
  兜底意味着一期不必集齐所有厂商，但小米凭据是必填的
- Android 13+ 未授权通知权限时，本地通知和厂商代发的通知栏消息都不展示。
  请求逻辑在 `chat/lib/wfc_notification_manager.dart` 的 `_requestAndroidNotificationPermission`
