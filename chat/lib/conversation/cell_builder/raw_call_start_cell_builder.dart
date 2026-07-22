import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';

import 'package:chat/pc/call_window/raw_voip_message_content.dart';
import 'package:chat/call/av_call_launcher.dart';

import 'call_start_display.dart';
import 'portrait_cell_builder.dart';

/// PC 端主窗口收到的通话开始消息使用 [RawVoipMessageContent] 占位，
/// 渲染样式与 [CallStartCellBuilder] 一致（状态文字 + 图标，对齐微信），
/// 点击按原类型重新发起通话。展示逻辑见 call_start_display.dart。
class RawCallStartCellBuilder extends PortraitCellBuilder {
  RawCallStartCellBuilder(super.context, super.model);

  @override
  Widget buildMessageContent(BuildContext context) {
    final info = _parsePayload();
    return callStartMessageTile(
      context,
      text: info.text,
      audioOnly: info.audioOnly,
      onTap: () => startAvCall(context, model.message.conversation, audioOnly: info.audioOnly),
    );
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

    final text = callStartStatusText(
      context,
      status: status,
      connectTime: connectTime,
      endTime: endTime,
      isSend: model.message.direction == MessageDirection.MessageDirection_Send,
      audioOnly: audioOnly,
    );
    return _CallInfo(audioOnly: audioOnly, text: text);
  }
}

class _CallInfo {
  final bool audioOnly;
  final String text;

  _CallInfo({required this.audioOnly, required this.text});
}
