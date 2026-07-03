# 桌面端（Windows / macOS / Linux）支持状态与问题记录

> 记录当前 `chat` 桌面端支持的状态、已知问题、Flutter 版本要求及后续待办。

---

## 1. 当前状态

| 平台 | 状态 | 说明 |
|------|------|------|
| macOS | ✅ 可构建运行 | `flutter build macos` 已通过，生成 `chat.app` |
| Windows | ⚠️ 目录已生成，未验证 | 标准 `chat/windows` 目录已生成，需 Windows 主机验证 |
| Linux | ⚠️ 目录已生成，未验证 | 标准 `chat/linux` 目录已生成，需 Linux 主机验证 |

---

## 2. Flutter 版本说明

### 当前环境版本

```text
Flutter 3.27.5-ohos-1.0.6 • channel [user-branch]
Framework • revision 757fcfcc7b
Engine • revision e672b006cb
Tools • Dart 3.6.2 • DevTools 2.40.0
```

路径：`/opt/flutter_flutter`

### 版本兼容性结论

- **Android / iOS / HarmonyOS**：继续使用该 `ohos` 分支。
- **macOS**：可以在此 `ohos` 分支下构建成功。
  - 原因：`imclient/macos` 已改为 **Objective-C++** 实现（`FlutterMethodChannel`），不依赖 `cpp_client_wrapper` C++ 头文件。
- **Windows / Linux**：**不能** 在该 `ohos` 分支下构建。
  - 原因：`imclient/windows` 与 `imclient/linux` 使用 C++ `flutter::MethodChannel`，需要官方 Flutter SDK 中的 `cpp_client_wrapper` 头文件。
  - 该 `ohos` 分支 SDK 中**没有**这些头文件（`find /opt/flutter_flutter -path '*cpp_client_wrapper*'` 无结果）。

### 建议

构建桌面端时，切换到对应平台的**官方 Flutter SDK**（例如 `stable` 3.27.x），再执行：

```bash
# macOS
flutter build macos

# Windows（需 Windows 主机或官方 SDK）
flutter build windows

# Linux（需 Linux 主机或官方 SDK）
flutter build linux
```

---

## 3. 已知问题与限制

### 3.1 `rtckit` 插件未声明桌面平台

- `rtckit/pubspec.yaml` 仅声明了 `android` 和 `ios` 平台。
- 因此桌面端**暂不支持音视频通话**。
- 即使编译通过，运行时相关功能也会报错或无法调用。

### 3.2 拍照 / 音视频通话在桌面端被主动禁用

`chat/lib/conversation/input_bar/plugin_board.dart` 中：

- `camera` 按钮
- `call` 按钮

在非 `android` / `ios` 平台时会提示：

```dart
Fluttertoast.showToast(msg: l10n.notSupportedOnCurrentPlatform);
```

这是预期行为，因为当前桌面端没有摄像头 / 通话 SDK 支持。

### 3.3 `WfcNotificationManager` 仅创建 Android 通知渠道

`chat/lib/wfc_notification_manager.dart`：

```dart
if (Platform.isAndroid) {
  // 创建 AndroidNotificationChannel
}
```

桌面端不会创建通知渠道，符合桌面端预期（macOS / Windows / Linux 通知机制不同）。

### 3.4 `libMarsWrapper.dylib` 存在两个缺失的 C 导出符号

macOS 预编译库 `imclient/macos/Frameworks/libMarsWrapper.dylib` 中缺少以下导出：

- `getProtoRevision`
- `setFavUser`

当前在 `ImclientPlugin.mm` 中已做兼容处理：

- `getProtoRevision`：返回空字符串 `""`
- `setFavUser`：macOS 下无操作（no-op）

后续若更新 macOS SDK，需要确认这两个符号是否补齐。

### 3.5 macOS 部署目标版本

已将 `chat/macos/Podfile` 和 `Runner.xcodeproj/project.pbxproj` 中的 `MACOSX_DEPLOYMENT_TARGET` 设为 `15.0`，以匹配 `libMarsWrapper.dylib` 的编译目标。

若后续升级 SDK 或重新编译 dylib，可能需要同步调整。

### 3.7 macOS 网络权限

macOS 应用默认启用 App Sandbox，必须在 `.entitlements` 文件中声明网络权限，否则会出现：

```text
ClientException with SocketException: Connection failed (OS Error: Operation not permitted, errno = 1)
```

已在以下文件启用：

- `chat/macos/Runner/DebugProfile.entitlements`
- `chat/macos/Runner/Release.entitlements`

新增的关键权限项：

```xml
<key>com.apple.security.network.client</key>
<true/>
```

`DebugProfile.entitlements` 原有 `com.apple.security.network.server`，Release 原有未配置，均已补齐。

注意：修改 entitlements 后需要重新执行 `flutter build macos`， entitlement 变更才会生效。

### 3.6 第三方插件警告

构建时可能出现以下警告，不影响构建：

```text
warning: The macOS deployment target 'MACOSX_DEPLOYMENT_TARGET' is set to 10.11,
but the range of supported deployment target versions is 10.13 to 26.5.99.
```

来源：`flutter_local_notifications` 等第三方 Pod，非本项目代码问题。

### 3.7 运行时报错修复

针对 macOS 桌面端运行日志中出现的问题，已做以下修复：

1. **会话列表为空 / 解析字段崩溃**
   - 日志：`type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'`（`imclient_method_channel.dart`）
   - 原因：macOS SDK 返回的会话信息是**扁平结构**，`conversationType`/`target`/`line` 直接位于顶层，没有嵌套 `conversation` 字段；Dart 端按移动端格式读取 `map['conversation']` 得到 null，导致崩溃并跳过所有条目。
   - 修复：`_convertProtoConversationInfo` / `_convertProtoConversationSearchInfo` 在 `conversation` 字段缺失时使用顶层 map 本身来构造 `Conversation`；`_convertProtoConversation` 也改为可接受 null 并返回默认对象。
   - 验证：修复后加载到 194 条会话，首页会话列表正常显示。

2. **WebView `opaque is not implemented on macOS`**
   - 日志：`UnimplementedError: opaque is not implemented on macOS`（`work_space.dart`）
   - 原因：桌面端 WebKit 插件未实现 `setBackgroundColor` 的 `opaque` 参数。
   - 修复：将 `setBackgroundColor` 用 `try/catch` 包裹，失败时仅打印日志，不阻断页面构建。

3. **设置页 `displayName` / `name` 空值崩溃**
   - 日志：`Null check operator used on a null value` / `LateInitializationError: Field 'name' has not been initialized.`（`settings/me_tab.dart`、`UserInfo`）
   - 原因：缓存占位对象 `UserRepo.getUserInfo` 创建 `UserInfo` 时未初始化 `name`（late 字段），UI 强制解包触发崩溃。
   - 修复：
     - `UserInfo.name` 改为默认空字符串 `String name = '';`。
     - `settings/me_tab.dart` 中改用 `??` 提供兜底显示。

4. **App 生命周期 `hidden` 状态未处理**
   - 日志：`Null check operator used on a null value`（`internal/app_state.dart`）
   - 原因：Flutter 3.27 新增的 `AppLifecycleState.hidden` 未在映射表中定义。
   - 修复：在 `parseStateFromString` 中加入 `hidden`，并增加兜底返回 `inactive`。

5. **`getAuthCode` / `getOnlineInfos` MissingPluginException**
   - 日志：`MissingPluginException(No implementation found for method getAuthCode on channel imclient)` 等
   - 原因：macOS 插件中这两个方法返回了 `FlutterMethodNotImplemented`。
   - 修复：
     - `getOnlineInfos` 返回空列表 `[]`。
     - `getAuthCode` 通过 `onOperationStringSuccess` 回调空字符串，避免 Dart 端未处理异常。
   - 同时 `rtckit` 在桌面端不再调用 `initProto`、`seEnableProximitySensor`、`addICEServer`，避免音视频插件的 MissingPluginException。

6. **默认头像使用 CachedNetworkImage 加载本地 asset 报错**
   - 日志：`ArgumentError: Invalid argument(s): No host specified in URI assets/images/user_avatar_default.png`
   - 原因：`Portrait` 组件对所有头像都使用 `CachedNetworkImage`，本地 asset 路径被当作网络 URL。
   - 修复：`Portrait` 检测到 `assets/` 路径或空路径时改用 `Image.asset`。

7. **fluttertoast 桌面端 MissingPluginException**
   - 日志：`MissingPluginException(No implementation found for method showToast on channel PonnamKarthik/fluttertoast)`
   - 原因：`fluttertoast` 没有 macOS 实现。
   - 修复：在 `imclient` macOS 插件中注册 `PonnamKarthik/fluttertoast` 通道的 no-op 处理，静默吞掉桌面端 toast 调用。

8. **平台通道非主线程调用警告**
   - 日志：`The 'imclient' channel sent a message from native to Flutter on a non-platform thread.`
   - 原因：C++ 回调在后台线程直接调用 `[FlutterMethodChannel invokeMethod:arguments:]`。
   - 修复：`InvokeDartMethod` 中判断 `NSThread.isMainThread`，非主线程时通过 `dispatch_async(dispatch_get_main_queue(), ...)` 投递到主线程。

9. **会话中消息不显示 / `isReceiptEnabled` 异常**
   - 日志：
     - 进入会话后消息列表空白
     - `MissingPluginException(No implementation found for method isReceiptEnabled on channel imclient)`
   - 原因：
     - macOS SDK 返回的**消息对象**与移动端不同，消息字段（`messageId`、`messageUid` 等）直接位于顶层，`conversation` / `content` 字段也缺失，Dart 端按原格式解析几乎全部失败。
     - `isReceiptEnabled` / `isGroupReceiptEnabled` / `isCommercialServer` / `isGlobalDisableSyncDraft` 在 macOS SDK 中没有对应导出。
   - 修复：
     - `_convertProtoMessage` 在 `conversation` / `content` 缺失时回退到顶层 map 自身。
     - `_convertProtoMessageContent` / `_convertProtoConversation` 增加 null 兼容，避免空字段导致整批消息被丢弃。
     - macOS 插件中把上述 4 个未导出方法统一返回 `@NO`，避免 `MissingPluginException`。

10. **进入会话目标错误 / 消息发送者异常**
    - 现象：点击某个会话进入后，标题/消息可能对应到错误的会话。
    - 原因：修复消息扁平结构时，把 `conversation` / `content` 都回退到顶层 map，导致会话信息扁平结构的字段污染了消息对象，会话目标被错误解析。
    - 修复：`_convertProtoMessage` 中消息仍优先使用嵌套的 `conversation` / `content` 字段，仅当确实缺失时才回退到顶层；同时把 `Message.fromUser` 默认空字符串，避免 `LateInitializationError`。

11. **`isUserEnableReceipt` / `isNoDisturbing` / `isMuteNotificationWhenPcOnline` MissingPluginException**
    - 日志：进入会话或收到消息时报 `MissingPluginException`。
    - 原因：macOS SDK 没有对应导出。
    - 修复：在 macOS 插件中统一返回 `@NO`。

12. **`getMessages` 方向参数错误**
    - 现象：进入会话后消息列表为空或顺序/内容不对。
    - 原因：macOS 插件把 Dart 的 `count > 0` 直接作为 C SDK 的 `direction` 参数，但两者语义不同。Dart 中 `count > 0` 表示向前（旧消息），`count < 0` 表示向后（新消息）；C SDK 的 `direction` 需要单独传递，`count` 始终为正数。
    - 修复：在 `handleGetMessages` 与 `handleGetMessagesByStatus` 中改为 `direction = count < 0`，`count = abs(count)`。

---

## 4. 已完成的改动

- `chat/macos`、`chat/windows`、`chat/linux` 目录已按 Flutter 模板生成并替换项目名。
- `imclient/macos` 从 C++ 改为 Objective-C++ 实现。
- `imclient/pubspec.yaml` 已声明 `windows`、`macos`、`linux` 平台。
- `chat/pubspec.yaml` 描述已更新为支持桌面端。
- 根目录 `README.md` 已补充桌面端编译说明与限制。

---

## 5. 后续待办

| 序号 | 任务 | 优先级 | 说明 |
|------|------|--------|------|
| 1 | Windows 真机/虚拟机验证 | 高 | 使用官方 Flutter SDK 编译并修复问题 |
| 2 | Linux 真机/虚拟机验证 | 高 | 使用官方 Flutter SDK 编译并修复问题 |
| 3 | `rtckit` 桌面端支持 | 中 | 若需桌面端音视频，需为 Windows/macOS/Linux 实现原生插件 |
| 4 | 桌面端拍照/文件选择适配 | 中 | 可用 `file_picker` / `image_picker` 桌面端实现替代 |
| 5 | 桌面端通知适配 | 低 | 使用各平台原生通知机制 |
| 6 | 补齐 `getProtoRevision` / `setFavUser` macOS 导出 | 低 | 更新 macOS SDK 后验证 |

---

## 6. 相关路径

- 插件 macOS 实现：`imclient/macos/Classes/ImclientPlugin.mm`
- 插件 macOS podspec：`imclient/macos/imclient.podspec`
- 插件 Windows 实现：`imclient/windows/`
- 插件 Linux 实现：`imclient/linux/`
- 应用 macOS 工程：`chat/macos/`
- 应用 Windows 工程：`chat/windows/`
- 应用 Linux 工程：`chat/linux/`
- 平台限制代码：`chat/lib/conversation/input_bar/plugin_board.dart`
- 通知代码：`chat/lib/wfc_notification_manager.dart`
