# webview_all_linux 1.2.1(本地补丁版)

来源:pub.dev `webview_all_linux: 1.2.1`(未包含上游的 `test/` 目录)。
仅改动 `linux/src/webview/webview_method_handler.cc`,Dart 侧与上游一致。
升级 webview_all_linux 时需要把下面的补丁重新套用。

这个包是 `webview_flutter` 在 Linux 上的实现(WebKitGTK),为什么直接依赖它这个
实现包、而不是它的门面包 `webview_all`,见 `chat/pubspec.yaml` 里的说明。

## 补丁:`dispose` 真正销毁 WebView(修工作台页签的 WebKitWebProcess 泄漏)

### 问题

`LinuxWebViewController.dispose()`(Dart)最终打到原生的 `dispose` 方法上,而上游
的实现只有两行:

```c
if (strcmp(method, "dispose") == 0) {
  gtk_widget_hide(GTK_WIDGET(webview->web_view));   // 只是藏起来
  webview->visible = FALSE;
  update_flutter_view_input_region(webview->plugin);
  respond(method_call, success_response());
  return;
}
```

WebView 依旧留在 `plugin->webviews` 这张哈希表里。而真正做释放的
`destroy_linux_webview()`(`gtk_widget_destroy` + 一串 unref)只被挂成这张表的
value-destroy 函数,全仓库没有任何一处调 `g_hash_table_remove(self->webviews, …)`
—— 也就是说**表只在插件自身销毁时整体析构,等于进程退出**。

后果:每个 `WebKitWebView` 背后是一个常驻的 `WebKitWebProcess`(约 100~200MB),
一旦创建就活到程序退出。工作台是多页签的,页内跳转开新页签、关掉再开,进程数
只增不减 —— 关页签时 Dart 侧 `dispose()` 看似正常返回,内存却一点不还。

用 `ps aux | grep WebKitWebProcess` 数进程即可复现:反复开关工作台页签,数字只涨。

### 补丁

`dispose` 分支里把 WebView 从表中摘掉,借 value-destroy 函数走完整的销毁流程。

摘除动作**必须延迟到 idle**,不能就地做:`destroy_linux_webview()` 会
`g_clear_object(&webview->method_channel)`,而此刻正在这个 channel 的方法回调
(`instance_method_call_cb`)里,就地销毁是 use-after-free。因此补丁先照常 hide +
respond,再把 `{plugin, id}` 丢进 `g_idle_add`,等回调返回后由主循环完成销毁。

`update_flutter_view_input_region()` 也一并挪到 idle 回调里,因为它要在 WebView
真的没了之后重算 FlView 的输入区域。

### 上游

已是 pub.dev 上的最新版(1.2.1,2026-07-08),上游未修。升级前先看
<https://github.com/abandoft/webview_all> 是否已修掉,修了就可以撤掉这份补丁。
