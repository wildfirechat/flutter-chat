import 'dart:io';

import 'package:flutter/material.dart';

/// 朋友圈页面外壳：统一处理 PC 独立窗口（macOS 全尺寸内容视图）下
/// 页面 AppBar 与左上角窗口红绿灯按钮重叠的问题，以及宽窗口下的内容限宽居中。
///
/// macOS 子窗口是 fullSizeContentView，页面内容从 y=0 开始，
/// AppBar 的 leading（返回键）会被红绿灯遮挡，这里在页面上方补一条
/// 与主题同色的安全条（对齐微信 macOS 的留白）。
class MomentPageScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  /// 内容是否限宽居中（与朋友圈主页 maxWidth 640 一致）。
  final bool centerContent;

  /// 页面背景色（安全条同色，黑底预览页传 Colors.black）。
  final Color? backgroundColor;

  /// macOS 红绿灯区域高度（fullSizeContentView 下内容从窗口顶部开始）。
  static const double _kMacTrafficLightInset = 28.0;

  /// 内容最大宽度（与 FeedListPage 一致）。
  static const double kMomentContentMaxWidth = 640.0;

  const MomentPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.centerContent = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = Platform.isMacOS ? _kMacTrafficLightInset : 0.0;
    Widget result = Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: centerContent
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: kMomentContentMaxWidth),
                  child: body,
                ),
              )
            : body,
      ),
    );
    if (backgroundColor != null) {
      // 安全条区域与页面同色（否则黑底页顶部会露出一条主题色）
      result = Container(color: backgroundColor, child: result);
    }
    return result;
  }
}
