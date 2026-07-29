import 'package:flutter/material.dart';
import 'package:imclient/message/rich_notification_message_content.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/wf_webview_window/wf_webview_window_manager.dart';
import 'package:chat/workspace/wf_webview_screen.dart';

import '../../ui_model/ui_message.dart';
import 'message_cell_builder.dart';

/// 富通知消息(参考 vue-pc-chat 的 RichNotificationMessageContentView.vue):
/// 居中的卡片,展示标题、描述、键值数据列表和附加身份信息,不区分收发方向。
///
/// 点击富通知时：移动端直接打开网页；桌面端用独立子窗口承载网页。
class RichNotificationCellBuilder extends MessageCellBuilder {
  late RichNotificationMessageContent richNotificationContent;

  RichNotificationCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    richNotificationContent = model.message.content as RichNotificationMessageContent;
  }

  static const double _maxWidth = 400;

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return null;
    }
    final String normalized = hex.startsWith('#') ? hex.substring(1) : hex;
    final int? value = int.tryParse(normalized, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(normalized.length <= 6 ? value | 0xFF000000 : value);
  }

  void _onTap(BuildContext context) {
    final url = richNotificationContent.exUrl?.trim();
    if (url == null || url.isEmpty) {
      showToast(msg: AppLocalizations.of(context)!.notSupported);
      return;
    }

    if (isDesktopShell) {
      WFWebViewWindowManager.instance
          .show(url: url, title: richNotificationContent.title);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WFWebViewScreen(url, title: richNotificationContent.title),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final content = richNotificationContent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidthByScreen = MediaQuery.sizeOf(context).width * 0.76;
        final double cardMaxWidth = maxWidthByScreen.clamp(220.0, _maxWidth).toDouble();
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _onTap(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          content.title,
                          style: AppText.base.copyWith(color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (content.desc.isNotEmpty)
                        Text(
                          content.desc,
                          style: AppText.base.copyWith(color: context.colors.textPrimary),
                        ),
                      if (content.datas != null && content.datas!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: content.datas!
                                .map((data) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              data.key,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.base.copyWith(color: context.colors.textPrimary),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              data.value,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.base.copyWith(
                                                color: _parseColor(data.color) ?? context.colors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      if (content.exName != null && content.exName!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: context.colors.hairlineSoft)),
                          ),
                          child: Text(
                            content.exName!,
                            style: AppText.base.copyWith(color: context.colors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
