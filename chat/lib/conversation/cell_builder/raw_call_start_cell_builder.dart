import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/message.dart';

import 'package:chat/pc/call_window/raw_voip_message_content.dart';
import 'package:chat/call/av_call_launcher.dart';
import 'package:chat/utilities.dart';
import 'package:chat/theme/app_typography.dart';

import 'portrait_cell_builder.dart';

/// PC 端主窗口收到的通话开始消息使用 [RawVoipMessageContent] 占位，
/// 这里把它渲染成带头像的普通消息样式，并支持点击按原类型重新发起通话。
class RawCallStartCellBuilder extends PortraitCellBuilder {
  RawCallStartCellBuilder(super.context, super.model);

  @override
  Widget buildMessageContent(BuildContext context) {
    final info = _parsePayload();

    final label = info.audioOnly ? '[语音通话] ${info.ext}' : '[视频通话] ${info.ext}';

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 10,
        style: AppText.lg,
      ),
    );
  }

  void _onTap(BuildContext context) {
    final info = _parsePayload();
    startAvCall(context, model.message.conversation, audioOnly: info.audioOnly);
  }

  _CallInfo _parsePayload() {
    final raw = model.message.content as RawVoipMessageContent;
    final payload = raw.encode();
    final binary = payload.binaryContent;

    bool audioOnly = false;
    int status = 0;
    int? connectTime;
    int? endTime;

    if (binary != null && binary.isNotEmpty) {
      try {
        final map = json.decode(utf8.decode(binary)) as Map<String, dynamic>;
        audioOnly = (map['a'] as int? ?? 0) > 0;
        status = map['s'] as int? ?? 0;
        connectTime = map['c'] as int?;
        endTime = map['e'] as int?;
      } catch (_) {}
    }

    String ext = '';
    if (status == CallStartEndStatus.kWFAVCallEndReasonHangup.index ||
        status == CallStartEndStatus.kWFAVCallEndReasonRemoteHangup.index ||
        status == CallStartEndStatus.kWFAVCallEndReasonAllLeft.index) {
      if (endTime != null &&
          endTime > 0 &&
          connectTime != null &&
          connectTime > 0) {
        final duration = endTime - connectTime;
        if (duration > 0) {
          ext = Utilities.formatCallTime(duration ~/ 1000);
        }
      } else if (connectTime == null || connectTime == 0) {
        if (status == CallStartEndStatus.kWFAVCallEndReasonHangup.index) {
          if (model.message.direction == MessageDirection.MessageDirection_Send) {
            ext = '已取消';
          } else {
            ext = '已拒绝';
          }
        } else {
          if (model.message.direction == MessageDirection.MessageDirection_Send) {
            ext = '对方已拒绝';
          } else {
            ext = '对方已取消';
          }
        }
      }
    } else if (status != CallStartEndStatus.kWFAVCallEndReasonUnknown.index) {
      ext = '未接通';
    }

    return _CallInfo(audioOnly: audioOnly, ext: ext);
  }
}

class _CallInfo {
  final bool audioOnly;
  final String ext;

  _CallInfo({required this.audioOnly, required this.ext});
}
