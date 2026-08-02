import 'dart:collection';

import 'package:flutter/material.dart';

/// 单行文本，超宽时把省略号放在中间（`头…尾`），而不是末尾。
/// 移动端会话标题用它，避免末尾的省略号和右上角的 more-action 按钮视觉重复。
class MiddleEllipsisText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  static const String _ellipsis = '...';

  const MiddleEllipsisText(this.text, {super.key, this.style});

  /// 裁剪结果缓存。会话列表里每次 notify 都会重建可见行,而算一次结果最多要做
  /// 「二分次数 + 2」次 TextPainter.layout —— 那是真正的文字排版,不能每帧重跑。
  /// 相同的 (文本, 样式, 可用宽度, 字号档位) 必然得到相同结果,直接记住即可。
  static final LinkedHashMap<_EllipsisKey, String> _cache = LinkedHashMap();
  static const int _cacheCapacity = 512;

  static String _cached(_EllipsisKey key, String Function() compute) {
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // 命中的挪到队尾,淘汰真正最久没用到的
      return hit;
    }
    final value = compute();
    _cache[key] = value;
    if (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveTextStyle =
        (style == null || style!.inherit) ? defaultStyle.merge(style) : style!;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    Widget buildText(String value,
        {TextOverflow overflow = TextOverflow.clip}) {
      return Text(value,
          style: effectiveTextStyle,
          maxLines: 1,
          softWrap: false,
          overflow: overflow);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite) {
          return buildText(text);
        }

        final result = _cached(
          _EllipsisKey(text, effectiveTextStyle, maxWidth, textScaler),
          () => _ellipsize(text, effectiveTextStyle, textDirection, textScaler,
              maxWidth),
        );

        // 连 1+1 个字都放不下：退化成普通的末尾省略。
        return result.isEmpty
            ? buildText(text, overflow: TextOverflow.ellipsis)
            : buildText(result);
      },
    );
  }

  /// 返回裁剪后的文本；返回空串表示连 `头1…尾1` 都放不下，调用方应退化成末尾省略。
  static String _ellipsize(String text, TextStyle style,
      TextDirection textDirection, TextScaler textScaler, double maxWidth) {
    final textPainter = TextPainter(
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    );

    try {
      // 候选串能否单行完整落在 maxWidth 内。
      // 关键：必须同时判断 didExceedMaxLines——中文每个字之间都可换行，
      // 过宽的候选会被 layout 折到第二行、首行宽度被夹到 <= maxWidth，
      // 只看 width 会误判为「放得下」，导致取字过多、渲染时半字被裁。
      bool fits(String candidate) {
        textPainter.text = TextSpan(text: candidate, style: style);
        textPainter.layout(maxWidth: maxWidth);
        return !textPainter.didExceedMaxLines && textPainter.width <= maxWidth;
      }

      if (fits(text)) {
        return text;
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

      if (best == 0) {
        return '';
      }

      // 还有余量就多给头部一个字（非对称利用剩余宽度）。
      final withExtraHead =
          '${chars.take(best + 1)}$_ellipsis${chars.takeLast(best)}';
      return fits(withExtraHead)
          ? withExtraHead
          : '${chars.take(best)}$_ellipsis${chars.takeLast(best)}';
    } finally {
      // TextPainter 持有原生 Paragraph，不释放会在滚动时持续堆积。
      textPainter.dispose();
    }
  }
}

class _EllipsisKey {
  const _EllipsisKey(this.text, this.style, this.maxWidth, this.textScaler);

  final String text;
  final TextStyle style;
  final double maxWidth;
  final TextScaler textScaler;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EllipsisKey &&
          text == other.text &&
          maxWidth == other.maxWidth &&
          textScaler == other.textScaler &&
          style == other.style;

  @override
  int get hashCode => Object.hash(text, style, maxWidth, textScaler);
}
