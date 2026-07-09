import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';

import 'package:chat/conversation/forward/pick_forward_page.dart';
import 'package:chat/pc/pc_pick_forward_dialog.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';

export 'package:chat/conversation/forward/pick_forward_page.dart' show OnForwardTargetsSelected;

/// 按平台形态呈现“转发给…”界面:桌面居中 Dialog(680x540),移动端整页 push。
///
/// [onSelected] 在界面关闭之后才回调,调用方不需要自己 pop。
Future<void> showPickForwardTarget(
  BuildContext context, {
  required OnForwardTargetsSelected onSelected,
  List<Message>? messages,
  bool oneByOne = false,
}) {
  if (isDesktopShell) {
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
