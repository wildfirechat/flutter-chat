import 'package:flutter/material.dart';

import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面端通用紧凑型弹窗包装器
/// 自动限制最大宽度、圆角、背景色，保证与桌面端设计视觉深度一致。
Future<T?> showPcDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 400,
  double? height,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: context.colors.scrim,
    builder: (dialogContext) {
      // 弹窗挂在根导航器上,调用方 context 若在 PCHome 的 Theme 子树之外
      // (如 _PCHomeState 自身),showDialog 捕获不到桌面主题,这里统一补上。
      return Theme(
        data: PcTheme.themeData(dialogContext),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          backgroundColor: dialogContext.colors.surface,
          elevation: 12,
          child: SizedBox(
            width: width,
            height: height,
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

/// [showPcDialog] 内部的标准骨架:52px 标题栏(标题 + 关闭) / 内容 / 60px 操作栏。
///
/// 与 PcPickUserView、PcPickForwardView 的手写骨架同形,新弹窗直接复用,
/// 不要再各写一遍 —— 这三处的头部高度、按钮形态一旦漂移,弹窗之间就会互相不像。
///
/// [primary] / [secondary] 传按钮文案与回调;[primary] 为 null 时只剩关闭,
/// 用于纯浏览型弹窗(如「我的投票」列表)。
class PcDialogFrame extends StatelessWidget {
  final String title;

  /// 标题右侧的补充说明(如多选投票的「已选 2/3」),随内容变化。
  final String? subtitle;
  final Widget child;
  final PcDialogAction? primary;
  final PcDialogAction? secondary;

  /// 操作栏左侧的附加内容(如「导出明细」这类次要入口)。
  final Widget? footerLeading;

  const PcDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.primary,
    this.secondary,
    this.footerLeading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasFooter = primary != null || secondary != null || footerLeading != null;
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(width: 0.5, color: colors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: PcTheme.paneTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        subtitle!,
                        style: AppText.xs.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              HoverBuilder(
                cursor: SystemMouseCursors.click,
                builder: (context, hovered) => GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: hovered ? colors.hoverOverlay : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close, size: 18, color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
        if (hasFooter)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(width: 0.5, color: colors.hairline)),
            ),
            child: Row(
              children: [
                if (footerLeading != null) footerLeading!,
                const Spacer(),
                if (secondary != null) ...[
                  OutlinedButton(
                    onPressed: secondary!.onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: secondary!.danger ? colors.danger : colors.textPrimary,
                      side: BorderSide(color: secondary!.danger ? colors.danger : colors.hairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      textStyle: AppText.sm,
                    ),
                    child: Text(secondary!.label),
                  ),
                  const SizedBox(width: 12),
                ],
                if (primary != null)
                  FilledButton(
                    onPressed: primary!.onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary!.danger ? colors.danger : colors.accent,
                      disabledBackgroundColor:
                          (primary!.danger ? colors.danger : colors.accent).withValues(alpha: 0.4),
                      foregroundColor: colors.onAccent,
                      disabledForegroundColor: colors.onAccent.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      textStyle: AppText.sm,
                    ),
                    child: primary!.busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                            ),
                          )
                        : Text(primary!.label),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// [PcDialogFrame] 操作栏的一个按钮。[onPressed] 为 null 即禁用态。
class PcDialogAction {
  final String label;
  final VoidCallback? onPressed;

  /// 破坏性操作(删除/结束),按钮走 danger 色。
  final bool danger;

  /// 提交中:主按钮显示转圈,并由调用方把 [onPressed] 置空。
  final bool busy;

  const PcDialogAction({
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.busy = false,
  });
}
