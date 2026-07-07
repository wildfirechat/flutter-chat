import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端发起音视频通话的统一入口(输入栏按钮与用户信息卡片共用):
/// - 单聊:直接按 [audioOnly] 指定类型发起,不弹选择菜单;
/// - 群聊:先弹选人对话框(自己默认选中且不可取消,最多 9 人),选完真正发起。
/// 已有通话时提示;通话页面的打开由 AVEngineCallback.onStartCall 统一处理。
void startAvCall(BuildContext context, Conversation conversation, {required bool audioOnly}) {
  if (avEngineKit.currentSession != null && avEngineKit.currentSession!.status != CallState.STATUS_IDLE) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.callInProgress);
    return;
  }
  switch (conversation.conversationType) {
    case ConversationType.Single:
      avEngineKit.startCall(conversation, [conversation.target], audioOnly);
      break;
    case ConversationType.Group:
      _pickGroupMembersAndStart(context, conversation, audioOnly);
      break;
    default:
      break;
  }
}

/// 用户信息卡片的快捷形态:对指定用户发起单聊通话。
void startSingleAvCall(BuildContext context, String userId, {required bool audioOnly}) {
  startAvCall(context, Conversation(conversationType: ConversationType.Single, target: userId), audioOnly: audioOnly);
}

Future<void> _pickGroupMembersAndStart(BuildContext context, Conversation conversation, bool audioOnly) async {
  final groupMembers = await Imclient.getGroupMembers(conversation.target);
  final candidates = groupMembers.map((e) => e.memberId).toList();
  if (!context.mounted || candidates.isEmpty) {
    return;
  }
  showPcDialog(
    context: context,
    width: 420,
    height: 560,
    builder: (dialogContext) => PickUserScreen(
      title: AppLocalizations.of(context)!.pickGroupMember,
      (pickerContext, members) {
        // 排除自己(disabledCheckedUsers 预选项),得到真正的被邀请方
        final participants = members.where((memberId) => memberId != Imclient.currentUserId).toList();
        if (participants.isEmpty) {
          Fluttertoast.showToast(msg: AppLocalizations.of(pickerContext)!.selectMemberToCall);
          return;
        }
        Navigator.pop(pickerContext);
        avEngineKit.startCall(conversation, participants, audioOnly);
      },
      maxSelected: 9,
      candidates: candidates,
      disabledCheckedUsers: [Imclient.currentUserId],
    ),
  );
}
