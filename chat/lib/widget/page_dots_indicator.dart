import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';

/// 通用分页圆点指示器:当前页为长条,其余为圆点。
/// 仅一页时不渲染(由使用方判断或 pageCount <= 1 时返回空)。
class PageDotsIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;

  const PageDotsIndicator({
    Key? key,
    required this.pageCount,
    required this.currentPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active
                ? context.colors.textPrimary
                : context.colors.textSecondary.withValues(alpha: 0.4),
          ),
        );
      }),
    );
  }
}
