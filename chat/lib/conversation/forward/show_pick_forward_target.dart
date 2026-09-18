import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';

import 'package:chat/conversation/forward/pick_forward_page.dart';
import 'package:chat/pc/pc_pick_forward_dialog.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/app_shell.dart';

export 'package:chat/conversation/forward/pick_forward_page.dart'
    show OnForwardTargetsSelected;

/// 按平台形态呈现“转发给…”界面:桌面居中 Dialog(680x540),移动端整页从底部升起。
///
/// 移动端用 `fullscreenDialog: true` 而不是底部弹窗:转发是满屏的,而弹窗路由会抹掉
/// 顶部安全区(`ModalBottomSheetRoute` 里的 `MediaQuery.removePadding(removeTop: true)`),
/// 满屏时状态栏留白得手工补。`fullscreenDialog` 在移动端主题的 Cupertino 转场下同样是
/// 从底部升起(见 theme/page_transitions.dart),而且返回键、键盘避让、AppBar 左上角
/// 自动变“关闭”都由 SDK 负责。半屏的选人弹窗见 widget/bottom_sheet_page.dart。
///
/// [onSelected] 在界面关闭之后才回调,调用方不需要自己 pop。
Future<void> showPickForwardTarget(
  BuildContext context, {
  required OnForwardTargetsSelected onSelected,
  List<Message>? messages,
  bool oneByOne = false,
}) {
  if (AppShell.isDesktopStyle) {
    return showPcDialog(
      context: context,
      width: 680,
      height: 540,
      builder: (dialogContext) => PcPickForwardView(
        messages: messages,
        oneByOne: oneByOne,
        onSelected: (targets, comment) {
          Navigator.pop(dialogContext);
          onSelected(targets, comment);
        },
      ),
    );
  }

  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (pageContext) => PickForwardPage(
        messages: messages,
        oneByOne: oneByOne,
        onSelected: (targets, comment) {
          Navigator.pop(pageContext);
          onSelected(targets, comment);
        },
      ),
    ),
  );
}
