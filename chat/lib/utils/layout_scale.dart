import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../viewmodel/font_size_view_model.dart';

/// 把字号档位换算成布局尺寸。
///
/// 文字由 MaterialApp 的 textScaler 全局放大(最高 1.45),但布局尺寸不能同倍放大:
/// 头像和图标放大没有可读性收益,只会把文字挤出屏幕。所以按元素性质分设上限。
///
/// 调用方必须在同一个容器里对「容器高度」和「容器内的图形」用配套的上限,
/// 否则会出现内容溢出。同一个尺寸只允许被缩放一次:[Portrait] 已经在内部对
/// 传入的 width/height 调用了 [watchScale],调用方就应当传未缩放的基准值。
class LayoutScale {
  LayoutScale._();

  /// 头像、图标等图形元素。1.2 以上再放大只是挤压同行的文字。
  static const double iconCap = 1.2;

  /// 行高、列表项 extent。容器内同时有图形和文字时用这个。
  static const double rowCap = 1.35;

  /// 纯文本容器。必须完整跟随字号,否则最大档位下文字会被裁掉。
  static const double textCap = double.infinity;

  /// 缩放 [base],并在字号变化时重建调用方。
  static double watchScale(BuildContext context, double base, {double cap = iconCap}) {
    return base * min(context.watch<FontSizeViewModel>().textScaleFactor, cap);
  }

  /// 同 [watchScale],但不建立依赖。用于 layout 回调(如 itemExtentBuilder)中,
  /// 或调用方已在 build 里自行监听的场景 —— 在 layout 阶段注册依赖是非法的。
  static double scale(BuildContext context, double base, {double cap = iconCap}) {
    return base * min(context.read<FontSizeViewModel>().textScaleFactor, cap);
  }
}
