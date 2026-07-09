import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 发起单聊音视频通话的统一入口(桌面输入栏按钮与用户信息卡片共用):
/// 直接按 [audioOnly] 指定类型发起,不弹选择菜单;已有通话时提示。
/// 通话页面的打开由 AVEngineCallback.onStartCall 统一处理。
void startSingleAvCall(BuildContext context, String userId, {required bool audioOnly}) {
  if (avEngineKit.currentSession != null && avEngineKit.currentSession!.status != CallState.STATUS_IDLE) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.callInProgress);
    return;
  }
  avEngineKit.startCall(Conversation(conversationType: ConversationType.Single, target: userId), [userId], audioOnly);
}
