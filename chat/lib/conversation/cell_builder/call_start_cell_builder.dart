import 'package:flutter/cupertino.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/call/av_call_launcher.dart';

import '../../ui_model/ui_message.dart';
import 'call_start_display.dart';

/// 通话消息 Cell：状态文字 + 通话类型图标（对齐微信的「已取消 📹 /
/// 通话时长 00:06 📞」样式），点击按原类型重拨。展示逻辑见 call_start_display.dart。
class CallStartCellBuilder extends PortraitCellBuilder {
  late CallStartMessageContent callStartMessageContent;

  CallStartCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    callStartMessageContent = model.message.content as CallStartMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final content = callStartMessageContent;
    return callStartMessageTile(
      context,
      text: callStartStatusText(
        context,
        status: content.status,
        connectTime: content.connectTime,
        endTime: content.endTime,
        isSend:
            model.message.direction == MessageDirection.MessageDirection_Send,
        audioOnly: content.audioOnly,
      ),
      audioOnly: content.audioOnly,
      onTap: () => startAvCall(context, model.message.conversation,
          audioOnly: content.audioOnly),
    );
  }
}
