import 'package:flutter/material.dart';
import 'package:chat/pc/pc_platform.dart';

/// 右栏(详情区)的内容宽度契约。
///
/// 右栏宽度 = 窗口宽 − 侧栏(60) − 中栏(298~420):最小窗口 900 时是 542px,
/// 1440 的窗口下超过 1000px。资料、设置这类阅读性内容不能跟着面板无限拉宽,
/// 否则一行里只剩左端一个标签、右端一个箭头,中间全是空的。
///
/// 只约束正文,不约束容器:列表/网格类页面(收藏、文件记录、组织架构)本来就该
/// 铺满面板,不要套这一层。移动端整页只有一栏,直接透传 child。
class PcPaneContent extends StatelessWidget {
  /// 正文栏宽。设置页原先各自硬编码的 680 就是这个值,统一收到这里。
  static const double defaultMaxWidth = 680;

  /// 正文与头部栏/面板边缘之间的留白。
  static const EdgeInsets defaultPadding = EdgeInsets.all(24);

  final Widget child;
  final double maxWidth;

  const PcPaneContent(
      {super.key, required this.child, this.maxWidth = defaultMaxWidth});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopShell) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
