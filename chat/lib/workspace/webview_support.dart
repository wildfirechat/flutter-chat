import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// 桌面两端的实现包。这里直接依赖它们是为了拿到平台 controller 上的
// openDevTools(见 [openWebViewDevTools]);其余平台上那两个 is 判断恒为 false。
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/utils/show_toast.dart';

/// 当前平台是否有内嵌 WebView 的实现。
///
/// webview_flutter 只有 Android / iOS / macOS 三个联邦实现,Windows、Linux
/// (以及未启用鸿蒙 fork 时的 ohos)上 `WebViewPlatform.instance` 为 null,
/// 此时 `WebViewController()` 会直接抛断言(A platform implementation for
/// `webview_flutter` has not been set),整页变红。
///
/// 判断源头取平台接口自身的 instance,而不是列平台名单:哪天某个平台补上了
/// 实现,这里自动就通了。所有内嵌网页入口都要先问这里,不支持时退化成用系统
/// 浏览器打开。
bool get isInlineWebViewSupported => WebViewPlatform.instance != null;

/// 内嵌 WebView 不可用时的占位:说明文案 + 跳系统浏览器。
class WebViewUnsupportedView extends StatelessWidget {
  const WebViewUnsupportedView({required this.url, super.key});

  /// 原始网址,为空时只显示说明文案(工作台未配置地址等情况)。
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: colors.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public_off_outlined,
            size: 48,
            color: colors.iconSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.webViewNotSupport,
            textAlign: TextAlign.center,
            style: AppText.base.copyWith(color: colors.textSecondary),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                url,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.xs.copyWith(color: colors.textTertiary),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => openInSystemBrowser(context, url),
              child: Text(l10n.openInSystemBrowser),
            ),
          ],
        ],
      ),
    );
  }
}

/// 工作台 H5 用来识别"宿主带 dsbridge 原生桥"的 UA 标记。
///
/// work.html 选择 JS 桥的顺序是:electron → **UA 含 WF-DSBridge** → uni-app →
/// `navigator.userAgentData` 判定。最后那条是个坑:`userAgentData` 只有 Chromium
/// 系浏览器才有,而 Windows 的 WebView2 正是 Chromium,于是被判成"桌面浏览器"
/// 拿到一个没有原生通道的 web 桥,`openUrl` 之类的调用发不出来(表现为工作台首页
/// 能开,点里面的应用没反应)。Linux 的 WebKitGTK 没有这个 API,反而落到后面的
/// 默认分支上,所以只有 Windows 坏。
///
/// 打上这个标记就在所有平台判定之前短路,直接选中 dsbridge 传输 —— 也正是
/// dsbridge_flutter 在每个平台上实现的那一套(prompt + `window._dswk`)。
const String kDsBridgeUserAgentTag = 'WF-DSBridge';

/// 给带 dsbridge 桥的 WebView 的 UA 追加 [kDsBridgeUserAgentTag]。
///
/// **必须在 loadRequest 之前调**:页面是在脚本执行时读 `navigator.userAgent` 的。
/// 采用追加而不是整体替换,免得丢掉平台原本的 UA(服务端与页面里其它 UA 判断还要用)。
Future<void> tagDsBridgeUserAgent(WebViewController controller) async {
  try {
    final ua = await controller.getUserAgent();
    if (ua == null || ua.isEmpty || ua.contains(kDsBridgeUserAgentTag)) {
      return;
    }
    await controller.setUserAgent('$ua $kDsBridgeUserAgentTag');
  } catch (e) {
    debugPrint('tagDsBridgeUserAgent failed: $e');
  }
}

/// 打开这个 WebView 的开发者工具(仅桌面)。
///
/// 桌面两端的平台 controller 都提供了,但 webview_flutter 的公共 API 没有,只能
/// 按平台强转:
/// - Windows(WebView2):DevTools 是一个**独立的真实窗口**,有自己的键盘焦点,所以
///   即使网页本体收不到键盘(WebView2 被挂在 HWND_MESSAGE 下),DevTools 里照样能
///   打字、能在 Console 里执行 JS。
/// - Linux(WebKitGTK):inspector 要先打开 developer extras 才能用。
///
/// 网页里右键"检查"用不了 —— 插件启动时就把 WebView2 的默认右键菜单关掉了。
Future<void> openWebViewDevTools(WebViewController controller) async {
  final platform = controller.platform;
  try {
    if (platform is WindowsWebViewController) {
      await platform.openDevTools();
    } else if (platform is LinuxWebViewController) {
      await platform.setDeveloperExtrasEnabled(true);
      await platform.openDevTools();
    } else {
      debugPrint('openDevTools: 当前平台不支持');
    }
  } catch (e) {
    debugPrint('openDevTools failed: $e');
  }
}

/// 用系统浏览器打开 [url],失败时 toast 提示。
Future<void> openInSystemBrowser(BuildContext context, String url) async {
  final failMessage = AppLocalizations.of(context)!.cannotOpenLink;
  final uri = Uri.tryParse(MediaUrlRedirector.redirect(url));
  if (uri != null &&
      await canLaunchUrl(uri) &&
      await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return;
  }
  showToast(msg: failMessage);
}
