import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Linux 实现包。这里直接依赖它是为了拿到平台 controller 上的 dispose
// (见 [disposeWebViewController]);其余平台上这个 is 判断恒为 false。
import 'package:webview_all_linux/webview_all_linux.dart';
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

/// 释放一个 WebViewController 背后的原生 WebView。
///
/// webview_flutter 的 [WebViewController] 没有 dispose(该库的已知缺口:移动端
/// 靠 GC/平台生命周期回收),只有 Linux 实现在平台 controller 上给了。关闭工作台
/// 页签时不调这一下,就会漏一个常驻的 WebKit web 进程(约 100~200MB)。
void disposeWebViewController(WebViewController controller) {
  final platform = controller.platform;
  if (platform is LinuxWebViewController) {
    // 释放是尽力而为:此时页面可能正在拆,再抛出去也没人处理。
    unawaited(platform.dispose().catchError(
          (Object err) => debugPrint('dispose webview failed: $err'),
        ));
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
