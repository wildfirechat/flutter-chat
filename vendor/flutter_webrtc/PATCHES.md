# flutter_webrtc 1.5.2(本地补丁版)

来源:pub.dev `flutter_webrtc: 1.5.2`,为修 Linux 桌面端子窗口(独立 Flutter 引擎)
拿不到 `FlutterWebRTC.Method` channel 的问题打了一个补丁。升级 flutter_webrtc 时
需要确认上游是否已修,未修则重新套用。

复制时删掉了体积大且构建用不到的 `example/`、`Documentation/`,其余与上游一致。

## 补丁 1:Linux 每个引擎各自注册(修 PC 通话子窗口 MissingPluginException)

`linux/flutter_webrtc_plugin.cc` — `flutter_web_r_t_c_plugin_register_with_registrar`

上游实现:

```cpp
void flutter_web_r_t_c_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  static auto* plugin_registrar = new flutter::PluginRegistrar(registrar);
  flutter_webrtc_plugin::FlutterWebRTCPluginImpl::RegisterWithRegistrar(plugin_registrar);
}
```

函数内 `static` 只在**第一次**调用时求值。主窗口启动时
`fl_register_plugins()` 先注册一次,`plugin_registrar` 就此固定为主窗口引擎的
registrar / messenger;之后 desktop_multi_window 每开一个子窗口,
`chat/linux/runner/my_application.cc` 的 window-created 回调虽然会再调一次本函数,
但复用的仍是主窗口的 messenger —— 新建的 MethodChannel 建在主窗口引擎上,
**子窗口引擎里根本没有 `FlutterWebRTC.Method` 的 handler**。

本项目 PC 端通话跑在独立 Call 子窗口里(见 `chat/lib/pc/call_window/`),
表现就是发起通话即:

```
MissingPluginException(No implementation found for method initialize on channel FlutterWebRTC.Method)
avEngineKit start preview error ... → CallEndReason.REASON_MediaError
```

同时 `RTCVideoRenderer.initialize()` 也炸在同一个 channel 上。

macOS 走 `-registerWithRegistrar:`、Windows 走 `PluginRegistrarManager::GetRegistrar`,
都是每个 registrar 一份,所以只有 Linux 有这个问题。

补丁:去掉 `static`,每个引擎各建一份 wrapper。

### 为什么不回收 wrapper

`flutter::PluginRegistrar` 析构 → `ClearPlugins()` → `~FlutterWebRTC` →
`FlutterWebRTCBase::~FlutterWebRTCBase()` → **`LibWebRTC::Terminate()`**,这是进程级
的。主窗口那份实例始终存活,子窗口关闭时若跟着析构,等于把整个进程的 libwebrtc
关掉,下一通电话能不能重新 `Initialize()` 起来没有保证。

所以这里与上游一样刻意不回收,代价是每个通话子窗口泄漏一份
`PeerConnectionFactory`(约几 MB + 3 个 libwebrtc 线程)。注意补丁前后
`LibWebRTC::Initialize()` 的调用次数完全一样(上游也是每个引擎构造一个
`FlutterWebRTCPluginImpl`,只是共用了错的 registrar),补丁没有引入新的全局状态。

Linux 侧的 `flutter/include/flutter/plugin_registrar.h` 里虽然抄来了
`PluginRegistrarManager`(Windows 的正解),但它依赖 `FlutterDesktopPluginRegistrar
SetDestructionHandler`,该符号在 GTK embedder 上不存在,模板一旦实例化就编不过,
因此没走这条路。

### 上游修复方向(如果要提 PR)

真正干净的做法是把 `LibWebRTC::Terminate()` 从 `~FlutterWebRTCBase` 里挪走(改成
引用计数或进程退出时调用),再按 registrar 建表 + 随引擎销毁回收。
