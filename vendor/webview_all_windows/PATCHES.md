# webview_all_windows 1.2.1(本地补丁版)

来源:pub.dev `webview_all_windows: 1.2.1`(未包含上游的 `test/` 目录)。
改动了 `windows/src/webview/webview.cc`(补丁 1)、
`windows/src/plugin/windows_host_api.{h,cc}`(补丁 2、3)与
`windows/src/webview/webview_host.{h,cc}`(补丁 4),Dart 侧与上游一致。
升级 webview_all_windows 时需要把下面的补丁重新套用。

这个包是 `webview_flutter` 在 Windows 上的实现(WebView2 + 纹理渲染),为什么直接
依赖它这个实现包、而不是它的门面包 `webview_all`,见 `chat/pubspec.yaml` 里的说明。

## 补丁 1:关掉 WebView2 的默认脚本对话框(修 dsbridge 在 Windows 上完全失效)

### 问题

工作台首页能打开,但页面里点任何东西都没反应 —— `openUrl`、`getAuthCode`、
`config` 一个都不触发。

dsbridge_flutter 的 JS→Dart 通道是靠**拦截 `window.prompt()`** 实现的:JS 侧把调用
编码成 `_dsbridge=<method>` 传给 prompt,Dart 侧在
`setOnJavaScriptTextInputDialog` 回调里解出方法名并派发
(见 dsbridge_flutter 的 `DWebViewController.fromPlatform`)。

这个包把链路铺齐了:`add_ScriptDialogOpening` 注册了 handler,原生侧也正确地
`GetDeferral` → 回 Dart → `put_ResultText` → `Accept`。**唯独漏了一个开关。**

WebView2 的文档写得很明确:

> ScriptDialogOpening runs when a JavaScript dialog (alert, confirm, prompt, or
> beforeunload) displays for the WebView. **This event only fires if the
> `ICoreWebView2Settings::AreDefaultScriptDialogsEnabled` property is set to
> FALSE.**

而 `AreDefaultScriptDialogsEnabled` 在整个包里**出现 0 次**(它设了
`IsStatusBarEnabled` 和 `AreDefaultContextMenusEnabled`,唯独没设这个)。默认值为
TRUE,所以 `ScriptDialogOpening` 永远不触发,`prompt()` 由 WebView2 自己弹原生框,
Dart 侧的回调是死的。

### 补丁

`Webview::SetJavaScriptDialogCallbacksEnabled()` 里跟着同步这个设置:只要 Dart 侧
注册了 alert/confirm/prompt 中的任意一个回调,就关掉默认对话框;全部取消时恢复。

这个函数是 Dart 侧 `setOnJavaScriptXxxDialog` 的落点,调用前已 `_ensureInitialized()`,
`settings_` 必定就绪。

### 影响面

改动只决定 JS 对话框由谁来弹。打上之后 Windows 与 Android / iOS / Linux 一致 ——
那几端本来就是 dsbridge 接管 alert/confirm/prompt。

### 上游

已是 pub.dev 上的最新版(1.2.1,2026-07-08),上游未修。升级前先看
<https://github.com/abandoft/webview_all> 是否已修掉,修了就可以撤掉这份补丁。

## 补丁 2:`~WindowsHostApi` 不再摘 pigeon handler / 不再注销窗口类(修 Windows 关子窗口崩溃)

### 问题

Windows 上关闭**任意** desktop_multi_window 子窗口(通话 / 媒体预览 / 朋友圈 /
搜索)都会崩进程。VS 附加抓到的栈:

```
flutter_windows.dll!????                                        ← 访问违例
flutter::BinaryMessengerImpl::SetMessageHandler(...)      Line 120
flutter::BasicMessageChannel<EncodableValue>::SetMessageHandler(...) Line 94
webview_all_windows::WindowsHostApi::~WindowsHostApi()    Line 53
flutter::PluginRegistrar::ClearPlugins()                  Line 43
flutter::PluginRegistrarWindows::~PluginRegistrarWindows()Line 46
flutter::PluginRegistrarManager::OnRegistrarDestroyed(...)Line 59
flutter::FlutterViewController::~FlutterViewController()  Line 28
FlutterWindow::Destroy()                    (desktop_multi_window)
FlutterWindow::MessageHandler(...)          ← 子窗口的 WM_DESTROY
```

原析构函数第一行是:

```cpp
WindowsHostApi::~WindowsHostApi() {
  webview_all_windows::WindowsWebViewHostApi::SetUp(messenger_, nullptr);  // ← 崩在这
  ...
}
```

`SetUp(messenger, nullptr)` 是 pigeon 生成的"摘 handler"写法,逐个 channel 调
`BasicMessageChannel::SetMessageHandler(nullptr)`,最终落到嵌入层的
`FlutterDesktopMessengerSetCallback()`。

但**插件析构只发生在引擎销毁的过程中**:
`~FlutterWindowsEngine` → `Stop()` → registrar destruction callback →
`~PluginRegistrarWindows` → `ClearPlugins()` → 本析构函数。而引擎析构里
messenger 与 engine 的解绑排在 `Stop()` **之前**,轮到插件析构时
messenger 上挂的 engine 已经是空,`FlutterDesktopMessengerSetCallback` 里
直接空指针解引用 → 访问违例。

主窗口的引擎只在进程退出时销毁,所以单窗口应用碰不到;本项目每个子窗口引擎
关闭时都会走一遍,于是"关任意子窗口必崩",且与子窗口跑什么业务无关
(webview 插件在 `chat/windows/runner/flutter_window.cpp` 的子窗口白名单里是
无条件注册的,四个窗口都有)。macOS / Linux 是另外两套实现,没有这条路径。

### 改动

`windows/src/plugin/windows_host_api.cc`,以 `[PATCH]` 注释标出:

- 删掉 `WindowsWebViewHostApi::SetUp(messenger_, nullptr)`。引擎马上就没了,
  handler 摘不摘没有意义。这也是其他 Windows 插件的普遍做法 —— 同样在子窗口
  白名单里的 `url_launcher_windows` 也用 pigeon,但它的
  `~UrlLauncherPlugin() = default`,压根不摘;`flutter::MethodChannel` 的析构
  同理不会去注销 handler。核对过白名单里其余几个
  (window_manager / screen_retriever_windows / permission_handler_windows /
  fvp / flutter_webrtc),没有第二个在析构里摘 handler 的。
- 删掉 `UnregisterClass(window_class_.lpszClassName, nullptr)`。窗口类
  `FlutterWebviewMessage` 是**进程级**的,而每个子窗口引擎都会再注册一次本
  插件:第二个实例的 `RegisterClass` 因重名失败(无妨,类已存在),但**先关掉
  的那个**实例会把这个类注销掉,之后主窗口再建 webview 就没有窗口类可用。
  留着不注销,代价是进程退出前多挂一个窗口类。

`instances_.clear()` 保留 —— `~WebviewBridge` 只调
`texture_registrar_->UnregisterTexture()`,不碰 message handler。

### 上游

上游 1.2.1 未修。真正干净的修法在 Flutter 嵌入层(插件析构应排在 messenger
解绑之前),插件侧只能规避。

## 补丁 3:`WebviewPlatform` 改为进程级单例(修 unsupported_platform)

### 问题

webview 子窗口拿不到 webview,Dart 侧一路 `PlatformException(unsupported_platform,
The platform is not supported)`:

```
WebView setBackgroundColor skipped on this platform: PlatformException(unsupported_platform, …)
tagDsBridgeUserAgent failed: PlatformException(unsupported_platform, …)
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: PlatformException(unsupported_platform, …)
```

这个错误码只有一个来源:`InitPlatform()` 返回 false,即
`WebviewPlatform::IsSupported()` 为假。而 `WebviewPlatform` 的构造做的是三件
**线程/进程级**的事:

1. `RoInitialize`;
2. 在**当前线程**上 `CreateDispatcherQueueController(DQTYPE_THREAD_CURRENT)`;
3. 建 D3D 设备(`GraphicsContext`)。

上游把它做成 `WindowsHostApi` 的 `unique_ptr` 成员 —— 每个引擎一份。单窗口应用
没问题,但本项目用 desktop_multi_window,子窗口引擎与主窗口**跑在同一个平台
线程**上,本插件又按引擎各注册一份,于是:

- 一个线程只能有一个 DispatcherQueue,第二份 `WebviewPlatform` 的
  `CreateDispatcherQueueController` 必然失败 → 构造函数提前 return →
  `valid_ = false` → `unsupported_platform`;
- webview 子窗口关闭时这份 `WebviewPlatform` 跟着析构,但
  `IDispatcherQueueController` 只是 Release 掉,DispatcherQueue 并不会从线程上
  摘掉(那要 `ShutdownQueueAsync`),所以**重开 webview 子窗口一样失败**,
  而且此后永久失败。

### 改动

`windows/src/plugin/windows_host_api.{h,cc}`,以 `[PATCH]` 注释标出:

- 成员 `std::unique_ptr<WebviewPlatform> platform_` 改为裸指针
  `WebviewPlatform* platform_`;
- `InitPlatform()` 里改用函数内 `static WebviewPlatform* const` 单例,**刻意不
  回收** —— 它绑在平台线程上,谁先关窗口都不该把另一个引擎正在用的 D3D 设备
  和消息队列带走(同 `vendor/flutter_webrtc/PATCHES.md` 里"为什么不回收
  wrapper"的取舍);
- 相应把两处 `platform_.get()` 改成 `platform_`。

`webview_host_`(WebView2 环境)仍是每个引擎一份,不受影响。

### 排查提示

`WebviewPlatform` 构造失败会打日志,但走的是 `OutputDebugStringA`
(`windows/src/util/logging.h`),**不进 PowerShell 控制台**,要在 Visual Studio
的「输出 → 调试」窗口或 DebugView 里看,前缀 `[webview_all_windows]`:

- `Creating DispatcherQueueController failed.` → 就是本补丁这条;
- `Windows::Graphics::Capture::GraphicsCaptureSession is not supported.` → 系统
  不支持,与本补丁无关;
- 两条都没有 → 卡在 `runtime_->available()`(combase/coremessaging 载不进来)
  或 `GraphicsContext::IsValid()`(D3D 设备建不起来),那是另一回事。

### 上游

上游 1.2.1 未修;上游只面向单窗口场景,不会遇到。

## 补丁 4:异步创建回调加存活令牌(修"打开 webview 子窗口就崩")

### 问题

`WebviewHost::CreateWebview()` 把裸的 `this` 捕进异步回调:

```cpp
CreateWebViewCompositionController(
    hwnd, [=, self = this](wil::com_ptr<ICoreWebView2CompositionController> controller,
                           std::unique_ptr<WebviewCreationError> error) {
      if (controller) {
        std::unique_ptr<Webview> webview(new Webview(
            std::move(controller), self, hwnd, owns_window, offscreen_only));  // ← self
```

`CreateCoreWebView2CompositionController()` 是**异步**的(要等 WebView2 浏览器进程
应答,首次尤其慢,几百毫秒起),完成回调由主线程消息循环派发。而 `WebviewHost`
归本引擎的 `WindowsHostApi::webview_host_` 所有,**子窗口引擎一销毁它就没了**;
`WindowsHostApi::CreateWebView` 那层 lambda 捕的 `this` 与 pigeon `result` 同理。

于是"开一个 webview 子窗口 → 创建还在飞 → 引擎/插件销毁 → 回调才到"就是
use-after-free。`Webview` 构造函数第 226 行 `CreateSurface(host->compositor(), …)`
第一个碰到已释放内存(2026-08-02 VS 抓栈,`m_ptr` 是随机值,不是 nullptr):

```
webview_all_windows_plugin.dll!winrt::com_ptr<…ICompositor>::add_ref()      ← m_ptr=0x6c6e3705064c579a
webview_all_windows_plugin.dll!winrt::com_ptr<…ICompositor>::com_ptr(const com_ptr&)
webview_all_windows_plugin.dll!webview_all_windows::WebviewHost::compositor() Line 61
webview_all_windows_plugin.dll!webview_all_windows::Webview::Webview(…)      Line 226
… WebviewHost::CreateWebview::__l2::<lambda_1>::operator()
… WebviewHost::CreateWebViewCompositionController::__l2::<lambda_1>::operator()(HRESULT, ICoreWebView2CompositionController*)
wildfirechat.exe!wWinMain                                                    ← 主线程消息循环派发
```

补丁 3 之前 Windows 子窗口的 `IsSupported()` 直接返回 false、根本走不到
`CreateWebview`,所以这条一直没现形;子窗口 webview 能用了之后才暴露出来。

### 改动

`windows/src/webview/webview_host.{h,cc}`,以 `[PATCH]` 标出:

- `WebviewHost` 新增 `std::shared_ptr<int> alive_` 存活令牌;
- `CreateWebview()` 的完成回调改为捕获 `std::weak_ptr`,`expired()` 时**整个丢弃**
  这次创建:不碰 `self`,也不回调 `callback`(它捕的 `WindowsHostApi` /
  pigeon reply 一样已经失效,调了就是补丁 2 那类"messenger 上 engine 已空"的崩溃)。
  丢弃前把已经建出来的 controller `Close()`(否则白留一个 WebView2 浏览器进程)、
  并销毁本该由 `Webview` 接管的消息窗口。

### 上游

上游 1.2.1 未修;上游只面向单窗口场景,插件与进程同寿,不会遇到。
