import 'package:flutter/material.dart';

/// 单行文本，超宽时把省略号放在中间（`头…尾`），而不是末尾。
/// 移动端会话标题用它，避免末尾的省略号和右上角的 more-action 按钮视觉重复。
class MiddleEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  static const String _ellipsis = '...';

  const MiddleEllipsisText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveTextStyle = (style == null || style!.inherit) ? defaultStyle.merge(style) : style!;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    Widget buildText(String value, {TextOverflow overflow = TextOverflow.clip}) {
      return Text(value, style: effectiveTextStyle, maxLines: 1, softWrap: false, overflow: overflow);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite) {
          return buildText(text);
        }

        final textPainter = TextPainter(
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        );

        // 候选串能否单行完整落在 maxWidth 内。
        // 关键：必须同时判断 didExceedMaxLines——中文每个字之间都可换行，
        // 过宽的候选会被 layout 折到第二行、首行宽度被夹到 <= maxWidth，
        // 只看 width 会误判为「放得下」，导致取字过多、渲染时半字被裁。
        bool fits(String candidate) {
          textPainter.text = TextSpan(text: candidate, style: effectiveTextStyle);
          textPainter.layout(maxWidth: maxWidth);
          return !textPainter.didExceedMaxLines && textPainter.width <= maxWidth;
        }

        if (fits(text)) {
          return buildText(text);
        }

        final chars = text.characters;
        final n = chars.length;

        // 二分查找：使 `头(k)…尾(k)` 仍能单行放下的最大对称字符数 k。
        int low = 1;
        int high = n ~/ 2;
        int best = 0;
        while (low <= high) {
          final mid = (low + high) ~/ 2;
          if (fits('${chars.take(mid)}$_ellipsis${chars.takeLast(mid)}')) {
            best = mid;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }

        // 连 1+1 个字都放不下：退化成普通的末尾省略。
        if (best == 0) {
          return buildText(text, overflow: TextOverflow.ellipsis);
        }

        // 还有余量就多给头部一个字（非对称利用剩余宽度）。
        final withExtraHead = '${chars.take(best + 1)}$_ellipsis${chars.takeLast(best)}';
        final result = fits(withExtraHead) ? withExtraHead : '${chars.take(best)}$_ellipsis${chars.takeLast(best)}';

        return buildText(result);
      },
    );
  }
}
