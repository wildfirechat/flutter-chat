import 'package:flutter/cupertino.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utilities.dart';

/// 通话消息状态文案（对齐微信）：通话时长/已取消/已拒绝/对方已拒绝/
/// 对方已取消/未接通，无法判定时退回类型标签。
///
/// [CallStartCellBuilder]（正常 CallStartMessageContent）与
/// [RawCallStartCellBuilder]（PC 主窗口 RawVoipMessageContent 占位）共用。
String callStartStatusText(
  BuildContext context, {
  required int status,
  int? connectTime,
  int? endTime,
  required bool isSend,
  required bool audioOnly,
}) {
  final l10n = AppLocalizations.of(context)!;
  final isHangup = status == CallStartEndStatus.kWFAVCallEndReasonHangup.index ||
      status == CallStartEndStatus.kWFAVCallEndReasonRemoteHangup.index ||
      status == CallStartEndStatus.kWFAVCallEndReasonAllLeft.index;

  if (isHangup) {
    if (endTime != null &&
        endTime > 0 &&
        connectTime != null &&
        connectTime > 0) {
      final duration = endTime - connectTime;
      if (duration > 0) {
        return '${l10n.callStatusDuration} ${Utilities.formatCallTime(duration ~/ 1000)}';
      }
    } else if (connectTime == null || connectTime == 0) {
      if (status == CallStartEndStatus.kWFAVCallEndReasonHangup.index) {
        return isSend ? l10n.callStatusCanceled : l10n.callStatusRejected;
      } else {
        return isSend
            ? l10n.callStatusRejectedByOther
            : l10n.callStatusCanceledByOther;
      }
    }
  } else if (status != CallStartEndStatus.kWFAVCallEndReasonUnknown.index) {
    return l10n.callStatusNoAnswer;
  }
  return audioOnly ? '[${l10n.audioCallAction}]' : '[${l10n.videoCallAction}]';
}

/// 通话消息内容展示：状态文字 + 通话类型图标（对齐微信），点击重拨由 onTap 处理。
Widget callStartMessageTile(
  BuildContext context, {
  required String text,
  required bool audioOnly,
  required VoidCallback onTap,
}) {
  final iconColor = DefaultTextStyle.of(context).style.color;
  return GestureDetector(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: AppText.lg,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          audioOnly ? CupertinoIcons.phone_fill : CupertinoIcons.video_camera_solid,
          size: 18,
          color: iconColor,
        ),
      ],
    ),
  );
}
