# imclient

野火 IM 协议栈的 Dart 封装，对上层（chat 应用与 avenginekit）提供连接管理、消息收发、
会话/用户/群组等 IM 能力的统一接口，入口为 `lib/imclient.dart` 中的 `Imclient` 类。

## 各平台实现

- **Android / iOS**:原生插件，通过 MethodChannel 调用野火原生 IM SDK。
- **桌面端（Windows / Linux / macOS）**:基于 `dart:ffi` 直连野火 IM SDK 动态库，
  方法分发在 Dart 侧实现（`lib/src/ffi/`），原生侧仅有共享垫片与打包。
- **鸿蒙（ohos）**:以 HAR 形式集成的原生插件。

事件（连接状态变更、收到消息、资料更新等）通过 `event_bus` 分发。
