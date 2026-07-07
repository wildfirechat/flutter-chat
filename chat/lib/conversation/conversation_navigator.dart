import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/pc/pc_shell_view_model.dart';

/// 打开会话的平台兼容入口:桌面 Shell 内走 PCShellViewModel
/// (右栏打开并同步列表选中态),移动端整页 push [ConversationScreen]。
/// 供共享页面(会话详情、用户详情等)在动作完成后跳转会话使用。
void navigateToConversation(BuildContext context, Conversation conversation) {
  PCShellViewModel? shell;
  try {
    shell = Provider.of<PCShellViewModel>(context, listen: false);
  } catch (_) {}
  if (shell != null) {
    shell.openConversation(conversation);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
    );
  }
}
