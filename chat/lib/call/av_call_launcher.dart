import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/call_window/main_avengine_kit_proxy.dart';
import 'package:chat/app_shell.dart';

/// 发起音视频通话的统一入口(输入栏按钮、用户信息卡片、通话记录气泡共用)。
///
/// 桌面/移动分流与"通话进行中"判断只在本文件出现:
/// - 移动端直接走 avenginekit,判断依据是 avEngineKit.currentSession;
/// - 桌面端经 [MainAvEngineKitProxy] 在独立 Call 窗口发起,判断依据是
///   Call 窗口是否存在(主窗口不初始化 avenginekit,currentSession 恒为 null)。
///
/// - 单聊:直接按 [audioOnly] 指定类型发起,不弹选择菜单;
/// - 群聊:先弹选人对话框(自己默认选中且不可取消,最多 9 人),选完真正发起;
/// - 已有通话时 toast 提示。
/// 通话页面的打开由 AVEngineCallback.onStartCall / Call 窗口统一处理。
void startAvCall(BuildContext context, Conversation conversation,
    {required bool audioOnly}) {
  if (_checkCallInProgress(context)) {
    return;
  }
  switch (conversation.conversationType) {
    case ConversationType.Single:
      _startCall(conversation, [conversation.target], audioOnly);
      break;
    case ConversationType.Group:
      _pickGroupMembersAndStart(context, conversation, audioOnly);
      break;
    default:
      break;
  }
}

/// 用户信息卡片的快捷形态:对指定用户发起单聊通话。
void startSingleAvCall(BuildContext context, String userId,
    {required bool audioOnly}) {
  startAvCall(context,
      Conversation(conversationType: ConversationType.Single, target: userId),
      audioOnly: audioOnly);
}

/// 参与者已确定时的直接发起形态(移动端会话内自带选人流程等)。
void startAvCallWithParticipants(
    BuildContext context, Conversation conversation, List<String> participants,
    {required bool audioOnly}) {
  if (_checkCallInProgress(context)) {
    return;
  }
  _startCall(conversation, participants, audioOnly);
}

bool _checkCallInProgress(BuildContext context) {
  final bool inProgress = AppShell.isDesktopStyle
      ? MainAvEngineKitProxy.instance.callActive
      : avEngineKit.currentSession != null &&
          avEngineKit.currentSession!.status != CallState.STATUS_IDLE;
  if (inProgress) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.callInProgress);
  }
  return inProgress;
}

void _startCall(
    Conversation conversation, List<String> participants, bool audioOnly) {
  if (AppShell.isDesktopStyle) {
    MainAvEngineKitProxy.instance
        .startCall(conversation, participants, audioOnly);
  } else {
    avEngineKit.startCall(conversation, participants, audioOnly);
  }
}

Future<void> _pickGroupMembersAndStart(
    BuildContext context, Conversation conversation, bool audioOnly) async {
  final groupMembers = await Imclient.getGroupMembers(conversation.target);
  final candidates = groupMembers.map((e) => e.memberId).toList();
  if (!context.mounted || candidates.isEmpty) {
    return;
  }
  showPickUserScreen(
    context,
    title: AppLocalizations.of(context)!.pickGroupMember,
    (pickerContext, members) {
      // 排除自己(disabledCheckedUsers 预选项),得到真正的被邀请方
      final participants = members
          .where((memberId) => memberId != Imclient.currentUserId)
          .toList();
      if (participants.isEmpty) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(pickerContext)!.selectMemberToCall);
        return;
      }
      Navigator.pop(pickerContext);
      _startCall(conversation, participants, audioOnly);
    },
    maxSelected: 9,
    candidates: candidates,
    disabledCheckedUsers: [Imclient.currentUserId],
    showOrganizationEntry: false,
  );
}
