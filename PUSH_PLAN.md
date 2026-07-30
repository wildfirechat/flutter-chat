# 离线推送实施计划（iOS / Android / 鸿蒙）

> 调研日期：2026-07-30
> 结论已逐条代码实证，文中所有 `文件:行号` 均可直接跳转核对。

## 0. 结论摘要

完成度比预期高很多：

| 环节 | 状态 | 剩余工作 |
| --- | --- | --- |
| 服务端 `push_server` | **已完备**，支持 10 个通道 | 零改动，只配后台 |
| `im-server` 推送路由 | **已完备** | 只改 `wildfirechat.conf` 三个地址 |
| imclient Flutter 桥接层 | **三端已通** | 零改动 |
| iOS 普通推送 | **代码已写完** | 只差 APNs 证书 + Xcode capability |
| iOS VoIP 推送 | **代码已写完**，被编译开关关着 | 打开 `USE_CALL_KIT=1` + VoIP 证书 |
| Android 厂商通道 | **已集成**（小米/华为/荣耀/vivo/OPPO/FCM） | 只差各厂商 appid/appkey，见第 3.5 节 |
| 鸿蒙 platform 上报 | **已修**（2026-07-30） | 见第 2 节 |
| 鸿蒙 Push Kit 取 token | 缺集成 | 见第 3.4 节 |

剩余要写的代码只有一处：**鸿蒙 PushKit 取 token**。其余全部是配置和凭据。

---

## 1. 现状盘点（已实证）

### 1.1 服务端 `push_server` —— 零改动

- 三个 endpoint：`/android/push`、`/ios/push`、`/harmony/push`，见 `push_server/src/main/java/cn/wildfirechat/push/PushController.java:23-34`，跑在 **8085**；admin UI 在 **8086**（默认 `admin` / `admin123`）
- 已实现通道：小米、华为 HMS、荣耀、OPPO、vivo、APNs、FCM、个推、UniPush、**鸿蒙 Push Kit**（`hm/HMPushServiceImpl.java`，走华为 oauth2 + `push-type` header）
- 证书 / AppKey 全部走后台页面存 DB，集群 30s 自动同步，**不依赖配置文件**
- 端口隔离由 `admin/PortAccessFilter.java` 强制：push 路径在 admin 端口 404，反之亦然

### 1.2 `im-server` 推送路由 —— 零改动

`im-server/broker/src/main/java/cn/wildfirechat/push/PushServer.java:94-116`：

```
iOS / iPad / AppleTV            → iOSPushServerUrl（并附带 voipDeviceToken）
Harmony / HarmonyPad / TV / Wear → harmonyPushServerUrl
Android / APad / AndroidTV/Wear  → androidPushServerUrl
其它                             → LOG.info("Not mobile platform {}")，直接不推
```

最后那个 else 分支是本次调研发现鸿蒙 P0 Bug 的关键，见第 2 节。

配置项在 `broker/config/wildfirechat.conf:424` 附近：

```
push.android.server.address  http://<push-server>:8085/android/push
push.ios.server.address      http://<push-server>:8085/ios/push
push.harmony.server.address  http://<push-server>:8085/harmony/push
```

### 1.3 imclient Flutter 桥接层 —— 三端已通，零改动

`setDeviceToken` / `setVoipDeviceToken` 原生实现全都在：

| 端 | 位置 | 落点 |
| --- | --- | --- |
| Android | `imclient/android/.../ImclientPlugin.java:321` | `ChatManager.Instance().setDeviceToken(token, pushType)` |
| iOS | `imclient/ios/Classes/ImclientPlugin.m:135` | `WFCCNetworkService setDeviceToken:pushType:` |
| ohos | `imclient/ohos/.../ImclientPlugin.ets:758` | `marsWrapper.setDeviceToken` |

Dart 侧入口 `imclient/lib/imclient.dart:453`、`:458`。

**关键事实**：`chat/android/app/build.gradle:67` 已经 `implementation fileTree(dir: "../../../imclient/android/android_client_aars")`，与 `android-chat` 用的是**同一个 `client-release.aar`**。所以 `ChatManager.Instance().setDeviceToken()` 在 Flutter 的 Android 侧原生可用，Android 侧的推送集成**完全不需要经过 Dart**。

### 1.4 iOS —— 代码已经写完了

- 普通推送：`chat/ios/Runner/AppDelegate.m:27-39` 请求通知权限并 `registerForRemoteNotifications`，`:116-133` 拿到 token 后转 hex 调 `setDeviceToken`。**这条链路是完整的。**
- VoIP 推送：`chat/ios/Runner/WFCCallKitManager.m:45-49` 建 `PKPushRegistry`，`:103-113` 把 VoIP token 通过 method channel 上抛 `didUpdateVoipToken`，Dart 侧 `chat/lib/call/callkit_service.dart:32-35` 接住并调 `Imclient.setVoipDeviceToken(token)`；`:115+` 还实现了 incoming VoIP payload 解析（读 `payload["wfc"]` 里的 sender / pushData）。**端到端也是完整的。**
- 唯一阻碍：`chat/ios/Runner.xcodeproj/project.pbxproj:643,832,863` 三处 `USE_CALL_KIT=0`，VoIP 那一整块被预处理器关掉了。

所以 iOS 侧是**配置任务，不是开发任务**。

### 1.5 Android —— 缺厂商 SDK 集成

`android-chat/push/` 是一个独立的 Android library module，入口 `PushService.init(Application, applicationId)`：

- 厂商探测顺序（`push/src/main/java/cn/wildfirechat/push/PushService.java:80-105`）：华为 → 荣耀 → 魅族 → vivo → OPPO → 小米 → FCM →
  **兜底：其它机型统一用小米推送**（`:101-105`）。这个兜底很务实，意味着一期不必集齐所有厂商。
- 各厂商拿到 token 后都直接调 `ChatManager.Instance().setDeviceToken(token, PushServiceType.X)`
- FCM 的启用条件（`:123-148`）会主动排除中国大陆：SIM + 网络都是 460、或（zh_CN + Asia/Shanghai）时不用 FCM
- 整个 `init` 被一个大 try-catch 包着（`:78`、`:118`），**任何厂商 SDK 初始化异常都会被静默吞掉**，排查时必须打断点或看日志

依赖清单（搬迁时必须一起带走）：

| 来源 | 内容 |
| --- | --- |
| `android-chat/push/build.gradle` | `com.huawei.hms:push:6.13.0.300`、`com.hihonor.mcs:push:8.0.12.307`、`firebase-bom:33.2.0` + `firebase-messaging:24.0.1`、`play-services-base:18.5.0` |
| `android-chat/push-aar-dep/` | `MiPush_SDK_Client_6_0_1-C_3rd.aar`、`push-internal-3.4.2.aar`（魅族） |
| `android-chat/push/libs/` | `mcssdk-2.0.2.jar`（OPPO）、`vivo_pushsdk_v2.3.1.jar` |
| `android-chat/push/src/main/AndroidManifest.xml` | 各厂商 receiver / service / meta-data + 权限，全部用 `${XXX}` 占位符 |
| `android-chat/chat/build.gradle:41-91` | `manifestPlaceholders` 全套，默认值都是空串 |
| **未入库** | `chat/agconnect-services.json`（华为）、`push/google-services.json`（FCM）—— 两个文件都不在仓库里，必须自己从后台下载 |

`android-chat/settings.gradle` 显示 `:push` / `:push-getui` / `:push-jpush` 是**三选一的互斥方案**，当前启用的是 `:push`（直连厂商）。

一个有利条件：`chat/android/app/src/main/AndroidManifest.xml:45` **已经有 `${applicationId}.main` 的 intent-filter**，正是 `PushService.showMainActivity()`（`PushService.java:158-163`）拉起 App 用的 action。通知点击拉起这块基础设施是现成的。

### 1.6 deviceToken 的上报时机（已实证）

- Android：`ChatManager.setDeviceToken` 先把 token / pushType 存进成员字段（`android-chat/client/.../ChatManager.java:9790-9791`），远程服务重连时自动重发（`:10990-10991`）。所以在 `Application.onCreate` 里早早调用是安全的。
- 鸿蒙：`marsWrapper.setDeviceToken` 直接透传给 native `mars::stn::setDeviceToken`，**没有 Java 层那种缓存重发**。hm-chat 因此把它放在 `ConnectionStatus == Connected` 之后调（`hm-chat/chat/src/main/ets/entryability/EntryAbility.ets:55-60`）。
- native 侧对 pushType 有范围校验，溢出会被置 0（`libmarswrapper.so` 内日志串 `setDeviceToken pushType overflow:%_, set pushType to 0`）。

**统一约定**：token 拿到后本地持久化，并在 `ConnectionStatusChangedEvent == Connected` 时补调一次 `setDeviceToken`。三端都按这个写，不依赖各端 SDK 的缓存差异。

---

## 2. P0 阻塞：鸿蒙端 platform 从未上报

### 现象推断

`im-server` 的 `PushServer.java:94-116` 要求 `session.getPlatform()` 命中白名单才推送，否则走 `LOG.info("Not mobile platform {}")` **一条推送都不发**。

### 根因（已实证）

hm-chat 在 `init` 时会显式告知 native 自己的平台：

```
hm-chat/client/src/main/ets/wfc/proto/proto.min.ets:372
protoProxy.setDeviceInfo(platform, deviceInfo.productModel, deviceInfo.displayVersion, deviceInfo.marketName);
```

platform 值来自 `Config.CURRENT_PLATFORM = Config.SDK_PLATFORM_HARMONY`（`hm-chat/client/src/main/ets/config.ets:80`），即 `PlatformType_Harmony = 10`。

而 flutter-chat 的鸿蒙侧**根本没有这一步**：

- `imclient/ohos/.../marsWrapper.ets:8-23` 的 `initProto(dbPath)` 只设 dbPath 和一堆 listener，**全文没有 `setDeviceInfo`，也没有 export 它**
- `imclient/ohos/.../ImclientPlugin.ets:224` 调用处也只传了 `filesDir`
- Dart 侧虽然有正确的平台号映射（`imclient/lib/imclient_platform.dart:98-125`，Harmony=10 / HarmonyPad=11 / HarmonyPC=12），但 `clientPlatformCode` **只被 `chat/lib/app_server.dart:24` 和 `chat/lib/pc/pc_qr_login_screen.dart:128` 消费，从未喂给 IM SDK**

结论：鸿蒙端上报给 im-server 的 platform 是 native 默认值，不是 10/11/12。**即使把 PushKit 全接好，服务端也不会发出任何推送。**

### 修复可行性（已实证）

native 能力是现成的，只缺 ETS 胶水。从 `imclient/ohos/har/marswrapper.har` 解包出的 `libs/arm64-v8a/libmarswrapper.so` 里可以找到 napi 绑定符号：

```
_ZN11MarsWrapper13setDeviceInfoEP10napi_env__P20napi_callback_info__
```

且 flutter 和 hm-chat 用的是**同一个 `libmarswrapper.so`**（flutter 侧 `import clientModule from '@wfc/marswrapper'`，hm-chat 侧 `import protoProxy from "libmarswrapper.so"`）。

### 修法（约 10 行）

1. `imclient/ohos/.../marsWrapper.ets`：加 `setDeviceInfo(platform, productModel, displayVersion, marketName)` 包装并 export
2. `initProto` 增加 platform 参数，内部调用 `setDeviceInfo`
3. `ImclientPlugin.ets:224` 的调用处按 `deviceInfo.deviceType` 选平台号（phone→10 / tablet→11 / 2in1→12），与 `imclient_platform.dart:105-125` 的映射保持一致

### 验证

登录后查 im-server 数据库 `t_user_session` 表的 `_platform` 字段，必须是 10/11/12。这一步不通过，鸿蒙推送后面全部无意义。

**顺带影响**：platform 上报错误不只影响推送，还影响多端在线互踢、PC 在线时手机静音等逻辑（`im-server/broker/.../MessagesPublisher.java:220-223`、`DatabaseStore.java:1867-1896` 都按 platform 分支）。所以这个修复本身独立于推送也值得做。

---

## 3. 一期（目标：三端跑通普通消息离线推送）

按依赖顺序排，每步都有独立验证点。

### 3.1 服务端准备（0 代码）

1. 部署 `push_server`，改 `application.properties` 换成 MySQL（默认 H2 只能单节点）
2. 访问 `http://<host>:8086/admin/`，用 `admin`/`admin123` 登录并**立即改密码**
3. 在「配置管理」逐平台填参数、上传证书
4. 改 `im-server` 的 `wildfirechat.conf` 三个 push 地址并重启

**验证**：admin 后台的推送记录 / 统计页面能看到 im-server 打过来的请求。

### 3.2 鸿蒙 platform 修复（P0，必须最先做）

见第 2 节。**验证**：`t_user_session._platform` == 10。

### 3.3 iOS（只做配置）

1. push_server 后台上传 APNs 证书（或 p8 key）
2. Xcode 打开 Push Notifications capability，确认 `Runner.entitlements` 的 `aps-environment` 与后台配的证书环境一致（dev 证书配 production 包必然静默失败）
3. 真机装 release/TestFlight 包，杀进程后由另一端发消息

**验证**：`t_user_session._token` 有值、`_push_type` 与证书环境匹配；push_server 日志有 `iOS push {...}`。

### 3.4 鸿蒙 PushKit 取 token

1. AGC 上为鸿蒙应用开通 Push Kit，配好证书指纹（否则 `getToken()` 报 `1000900010`）
2. `chat/ohos/entry/src/main/module.json5` 补权限
3. 在 `chat/ohos/entry/src/main/ets/entryability/EntryAbility.ets`（当前只有 24 行样板）里 `pushService.getToken()`，拿到后调 `setDeviceToken(8, token)`
   - 最简：直接 import imclient HAR 调用（`marsWrapper.ets:738` 已 export `setDeviceToken`）
   - 时机按第 1.6 节约定，放在连接成功之后
4. push_server 后台配鸿蒙通道（`HMPushServiceImpl` 用的是华为 oauth2 client_id/secret）

**验证**：`t_user_session._token` 有值、`_push_type` == 8；push_server 收到 `/harmony/push` 请求。

### 3.5 Android 厂商通道 —— 已完成（2026-07-30）

采用「Android library module」方案，完全不碰 Dart 层：token 由厂商 SDK 回调后直接调
`ChatManager.Instance().setDeviceToken()`（`chat/android/app` 与 `:push` 共用同一个
`client-release.aar`）。

新增/改动的文件：

| 文件 | 说明 |
| --- | --- |
| `chat/android/push/` | library module，`cn.wildfirechat.push`，源自 `android-chat/push/` |
| `chat/android/push/libs/` | `mcssdk-2.0.2.jar`(OPPO)、`vivo_pushsdk_v2.3.1.jar` |
| `chat/android/push-aar-dep/` | `MiPush_SDK_Client_6_0_1-C_3rd.aar` |
| `chat/android/push/consumer-rules.pro` | 厂商 SDK 混淆规则，走 `consumerProguardFiles` 自动传给 app |
| `chat/android/settings.gradle` | `include ":push"` |
| `chat/android/build.gradle` | 加华为/荣耀 maven 仓库 + agcp / google-services classpath |
| `chat/android/app/build.gradle` | `manifestPlaceholders`、`implementation project(':push')`、条件 apply 插件 |
| `chat/android/app/.../WfcApplication.java` | `initFlutterEngine()` 之后调 `PushService.init(this, getPackageName())` |

#### 凭据填在哪

厂商 appid/appkey 从 `chat/android/local.properties` 读（该文件不入库），缺失即为空串，
对应厂商自行跳过注册，不影响构建和其他厂商：

```properties
push.xiaomi.appId=
push.xiaomi.appKey=
push.honor.appId=
push.vivo.appId=
push.vivo.appKey=
push.oppo.appKey=
push.oppo.appSecret=
```

华为和 FCM 不走 properties，各自需要一个 json 放在 `chat/android/app/` 下：
`agconnect-services.json`、`google-services.json`。这两个 gradle 插件**缺 json 会让构建
直接失败**，所以 `app/build.gradle` 里按文件存在才 `apply`——不放 json 时构建正常，只是
这两个通道不生效。

#### 相对 android-chat 的有意偏差

搬迁不是照抄，下面几处是刻意改的：

1. **剔除魅族**。推送服务端已移除魅族支持（`AndroidPushType` 里 3 号被注释掉），客户端留着
   没有意义。`push-internal-3.4.2.aar` 也没有拷过来。
2. **修了荣耀 pushType 上报错误**。`android-chat` 的 `HonorPushService.onNewToken` 上报的是
   `PushServiceType.HMS`(2) 而不是 `Honor`(9)，会让推送服务端拿荣耀 token 去走华为 HMS 通道，
   必然失败。已改为 `Honor`。
3. **修了 FCM 判定的 NPE**。原 `useGoogleFCM` 的条件是
   `!isEmpty(no) && isEmpty(simNo)`，随后又对 `simNo` 调 `startsWith`——`getSimOperator()`
   返回 null 时（无 SIM 卡）直接 NPE。该 NPE 会被 `init` 的大 try-catch 吞掉，**导致整个推送
   初始化中断、所有通道都不注册**。已改成「运营商信息取得到就按 460 判断，取不到就退化为按
   区域+时区判断」。
4. **小米 meta-data 改用容错读法**。`<meta-data android:value>` 的类型由 aapt 按字面量推断，
   纯数字若放得进 int32 会被编成整型，此时 `getString()` 返回 null → 小米推送静默注册失败
   （原代码给魅族做了 `"" + get()` 兜底，给小米却没做）。小米是所有未知机型的兜底通道，
   这里失败代价最大，已统一走 `metaDataAsString()`。
5. **`ProcessLifecycleOwner` 观察者改用 `DefaultLifecycleObserver`**，依赖从已废弃的
   `lifecycle-extensions:2.2.0` 换成 `lifecycle-process:2.8.7`。`@OnLifecycleEvent` 的反射
   支持在 lifecycle 2.6 起已被移除，而 Flutter 自身会把 lifecycle 拉到 2.6+，继续用会静默失效。
6. **push 模块的 manifest 不再声明 `READ/WRITE_EXTERNAL_STORAGE` 和 `READ_PHONE_STATE`**。
   app 模块声明存储权限时带了 `android:maxSdkVersion`（28/32），library 若无限制地再声明一次，
   manifest 合并取并集会把那个限制丢掉。`READ_PHONE_STATE` 则是根本不需要：
   `getNetworkOperator()` / `getSimOperator()` 都不要求该权限。
7. **删掉了死代码**：未被赋值的 `HuaweiApiClient` 字段与 `destroy()`、未被调用的
   `isXiaomiConfigured()`、`import static ...Constants.MessageNotificationKeys.TAG` 这个
   引 Firebase 内部常量当 TAG 的写法。

#### 已验证 / 未验证

已跑过并通过：

- `./gradlew :push:tasks` —— 构建脚本求值、插件解析
- `./gradlew :push:assembleDebug` —— **厂商 SDK 的 API 兼容性**（只有一条 deprecation 提示）
- `./gradlew :app:processDebugMainManifest` —— manifest 合并成功，`${...}` 占位符 0 残留，
  五个厂商组件都进了合并产物，存储权限的 `maxSdkVersion` 未被并集破坏
- `./gradlew :app:checkDebugDuplicateClasses` —— 与全部 Flutter 插件共存无重复类

未验证：

- **release 包的 minify/shrinkResources**。`consumer-rules.pro` 按各厂商文档写全了，但没做
  release 构建实测。首次出 release 包时要专门验一次推送。
- 真机行为（需要凭据才能验）。

#### 其余已知坑

- 小米推送必须判主进程（`shouldInitXiaomi`），多进程会重复注册
- 华为缺 `agconnect-services.json` 时 `AGConnectServicesConfig.fromContext(...)` 会抛异常，
  被 `init` 的 try-catch 吞掉 → 表现为"什么都没发生"，不是崩溃
- FCM 会引入 gms 依赖，国内包体和合规是问题 → 后续按渠道拆 flavor，国内包不放
  `google-services.json` 即可（插件不 apply，通道不生效）
- `POST_NOTIFICATIONS` 运行时权限：`app/src/main/AndroidManifest.xml:4` 已声明，需确认
  Dart 侧有请求
- 厂商探测顺序：华为 → 荣耀 → vivo → OPPO → 小米 → FCM → **兜底小米**

**真机验证**：logcat 出现 `setDeviceToken <token> <type>`（`ChatManager.java:9789`）和
`push service type <n>`；`t_user_session._push_type` 与机型匹配；push_server 日志有
`Android push {...}`。

### 3.6 一期不做的事

远程通知点击跳转、角标、VoIP、OPPO/vivo。一期只要求"杀进程后能收到通知栏消息"。

---

## 4. 二期

1. **OPPO / vivo 通道**：补账号 + 占位符，代码已在模块里
2. **远程通知点击跳转**：厂商 SDK 拉起 `${applicationId}.main`（intent-filter 已存在），需要在 `MainActivity` 解析 intent 把会话信息传给 Dart 走 `chat/lib/app_navigator.dart` 跳转。当前 `chat/lib/wfc_notification_manager.dart` 只处理本地通知，需要扩一条远程通知入口
3. **VoIP 推送**：
   - iOS：`USE_CALL_KIT=1` + VoIP 证书，代码已完备（第 1.4 节）
   - 鸿蒙：`PushMessageAbility` + `voipCall.reportIncomingCall`，hm-chat 有完整参照实现（`hm-chat/chat/src/main/ets/entryability/PushMessageAbility.ets`）
   - Android：`PushMessageType.VOIP_INVITE/BYE/ANSWER` 走透传
4. **角标**：iOS 靠 push_server 下发 `unReceivedMsg`；Android 各家 API 不同
5. **隐藏推送详情**：`PushMessage.isHiddenDetail` 服务端已支持，需接到设置项

---

## 5. 凭据清单（这是一期真正的关键路径）

代码工作量不大，**申请周期才是瓶颈**，建议立刻并行启动：

「客户端」列指 `chat/android/local.properties` 的键或需要放进 `chat/android/app/` 的文件；
「推送服务端」列指 push_server 8086 后台的配置项。

| 平台 | 需要申请 | 客户端 | 推送服务端 |
| --- | --- | --- | --- |
| 小米 | AppID / AppKey / AppSecret | `push.xiaomi.appId`、`push.xiaomi.appKey` | AppSecret |
| 华为（Android HMS） | AGC 应用 + Push 开通 | `app/agconnect-services.json` | client_id / secret |
| 荣耀 | AppID + 后台密钥 | `push.honor.appId` | ClientId / ClientSecret |
| vivo | AppID / AppKey / AppSecret | `push.vivo.appId`、`push.vivo.appKey` | AppID / AppKey / AppSecret |
| OPPO | AppKey / AppSecret / MasterSecret | `push.oppo.appKey`、`push.oppo.appSecret` | AppKey / MasterSecret |
| FCM（海外包） | Firebase 项目 | `app/google-services.json` | service account json |
| 鸿蒙 Push Kit | AGC 鸿蒙应用 + Push 开通 + 证书指纹 | 待接入（第 3.4 节） | client_id / secret |
| APNs | 推送证书 or p8 key（dev + prod 两套） | 无（代码已完备） | 上传证书 |
| APNs VoIP（二期） | 独立 VoIP 证书 | `USE_CALL_KIT=1` | 上传证书 |

注意客户端和推送服务端两侧都要配，只配一侧不通。客户端凭据决定「能不能拿到 token」，
服务端凭据决定「能不能把消息发给厂商」。

---

## 6. pushType 契约表（全链路必须一致）

来源 `push_server/src/main/java/cn/wildfirechat/push/android/AndroidPushType.java`，客户端侧对应 `android-chat/push/.../PushService.java:63-74` 的 `PushServiceType`：

| 值 | 通道 |
| --- | --- |
| 1 | 小米 |
| 2 | 华为 HMS |
| ~~3~~ | ~~魅族~~（服务端已移除） |
| 4 | vivo |
| 5 | OPPO |
| 6 | FCM |
| 7 | 个推 |
| 8 | 极光 |
| 9 | 荣耀 |
| 10 | UniPush v2 |

**鸿蒙特例**：hm-chat 传的也是 8，但因为走独立的 `/harmony/push` endpoint，与 Android 的 8=极光不冲突。`HMPushServiceImpl.java:134` 只用 pushType 区分 `hm` 与 `unipush_hm` 两种子类型。

iOS 的 pushType 分开发 / 发布两种，由 SDK 按证书环境上报（`push_server/push.md` 附录）。

---

## 7. 排查链路（收不到推送时按序走）

摘自 `push_server/push.md` 第七节，加上本次调研补充的锚点：

1. 确认 App 是**杀进程**状态。退到桌面时 App 仍活着，走的是本地通知，不经推送服务
2. 客户端是否拿到 token 并调了 `setDeviceToken`？Android 看 logcat 的 `setDeviceToken <token> <type>`（`ChatManager.java:9789`）
3. **`t_user_session` 表的 `_token` / `_push_type` / `_platform` 三个字段**——这是判断客户端上报是否成功的第一道锚点。`_platform` 不对（鸿蒙 P0）会导致 im-server 直接不推
4. 自定义消息必须 `pushContent` 或 `pushData` 至少一个非空，且 `PersistFlag` 必须是存储或存储计数
5. 目标用户 7 日内必须登录过，超过不推
6. 目标用户是否全局静音 / 会话静音？是否有 PC/Web 在线且开了"PC 在线时手机静音"？
7. im-server 日志：`Send push to {}, message from {}`
8. push_server 日志：`Android push {...}` / `iOS push {...}`，核对 token 和 type 与第 3 步一致
9. 到这一步之后就是厂商侧问题了，按厂商文档调
10. Android 用户侧设置也会拦：允许后台运行、允许自启动、允许后台弹界面、允许显示通知

`android-chat/push/.../PushService.java:78` 那个大 try-catch 会吞掉所有厂商 SDK 初始化异常——排查第 2 步时如果日志什么都没有，直接在 `init` 里打断点。

---

## 8. 已评估但不采用的方案

留档，避免以后重复讨论。

### 8.1 个推 / 极光

前提成立（收费），但理由要说对：它们卖的是"一套 API 打通所有厂商 + 自建长连兜底 + 到达率统计"，而这三件事我们已经有了——野火自带 mars 长连，`push_server` 就是我们自己的"个推云"。反过来，**厂商通道本身全部免费**，绕开它们的代价只是几个开发者账号的一次性申请成本。

`getui-flutter-plugin`（MIT，Android/iOS/**ohos** 三端全覆盖）是目前唯一三端齐全的推送 Flutter 插件。如果一期时间被压死，可以用它先跑通（push_server 的 `GetuiPush` 通道 + `android-chat/push-getui` 模块都已就绪，pushType=7），但那是**临时方案**：拿到的是个推 cid 而非厂商 token，厂商通道对接在个推云内部，出问题无法自行排查。它的 Dart 薄 API + 三端原生 + ohos HAR 的工程结构值得当模板参考。

### 8.2 完全自建通道（UnifiedPush / ntfy / Gotify / 自建 MQTT）

开源，但**在国内 Android 和鸿蒙 NEXT 上不可行**：都要求 App 自己维持后台长连接，而"杀进程 / 被系统冻结后还能收到消息"恰恰是离线推送要解决的唯一问题。野火的 mars 长连**就已经是这条路**，正因为它杀进程后失效才需要厂商通道。再叠一层无增量。

### 8.3 开源厂商聚合库

- [MixPush](https://github.com/taoweiji/MixPush)（Apache-2.0）：小米/华为/魅族/OPPO/vivo + APNs，带 Java 服务端。**不支持荣耀，不支持鸿蒙 NEXT**，README 的 TODO 里 FCM 和 Flutter 插件还没做
- [XPush](https://github.com/xuexiangjys/XPush)、[OSVsPush](https://github.com/hackycy/OSVsPush)、[PushLibrary](https://github.com/YoloHuang/PushLibrary)、[PushSDK](https://github.com/zhangjf88888/PushSDK)：同类，覆盖更窄
- [ym_flutter_push](https://github.com/haomiao33/ym_flutter_push)（MIT，6 star）：小米/华为/OPPO/vivo/魅族 + APNs，直连厂商。不支持荣耀和鸿蒙，成熟度不足以当依赖，但它把厂商 SDK 包进 Flutter plugin 的 gradle / manifestPlaceholders 写法可以参考

**不采用的理由**：这些库解决的问题和 `android-chat/push/` **完全一样**，而后者已支持荣耀、服务端已是 `push_server`、pushType 编号已对齐全链路。换过去等于用覆盖更窄的实现替掉能用的，还要重新对齐契约。

### 8.4 Flutter 层现成插件

- FCM：`firebase_messaging` 官方成熟，但国内无 GMS 不可用
- 国内厂商：**没有任何维护良好的官方 Flutter 插件覆盖小米/华为/荣耀/OPPO/vivo**。华为只有 `huawei_push`（旧 HMS Android，非鸿蒙 NEXT），小米/OPPO/vivo/荣耀一个都没有
- 鸿蒙 NEXT：没有现成 push 插件，社区做法就是自己写 HAR 适配层

"找一个现成 Flutter 插件搞定三端"这条路不存在（个推那个除外，见 8.1）。
