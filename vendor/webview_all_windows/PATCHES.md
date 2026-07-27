# webview_all_windows 1.2.1(本地补丁版)

来源:pub.dev `webview_all_windows: 1.2.1`(未包含上游的 `test/` 目录)。
仅改动 `windows/src/webview/webview.cc` 一处,Dart 侧与上游一致。
升级 webview_all_windows 时需要把下面的补丁重新套用。

这个包是 `webview_flutter` 在 Windows 上的实现(WebView2 + 纹理渲染),为什么直接
依赖它这个实现包、而不是它的门面包 `webview_all`,见 `chat/pubspec.yaml` 里的说明。

## 补丁:关掉 WebView2 的默认脚本对话框(修 dsbridge 在 Windows 上完全失效)

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
