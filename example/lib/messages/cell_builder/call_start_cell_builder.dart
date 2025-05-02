import 'package:flutter/cupertino.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';
import 'package:wfc_example/utilities.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class CallStartCellBuilder extends PortraitCellBuilder {
  late CallStartMessageContent callStartMessageContent;

  CallStartCellBuilder(MessageCell cell, UIMessage model) : super(cell, model) {
    callStartMessageContent = model.message.content as CallStartMessageContent;
  }

  @override
  Widget getContentAres(BuildContext context) {
    String ext = "";
    if (callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonHangup.index ||
        callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonRemoteHangup.index ||
        callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonAllLeft.index) {
      if (callStartMessageContent.endTime != null &&
          callStartMessageContent.endTime! > 0 &&
          callStartMessageContent.connectTime != null &&
          callStartMessageContent.connectTime! > 0) {
        int duration = callStartMessageContent.endTime! - callStartMessageContent.connectTime!;
        if (duration > 0) {
          ext = Utilities.formatCallTime(duration ~/ 1000);
        }
      } else if (callStartMessageContent.connectTime == null) {
        if (callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonHangup.index) {
          if (model.message.direction == MessageDirection.MessageDirection_Send) {
            ext = "已取消";
          } else {
            ext = "已拒绝";
          }
        } else if (callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonRemoteHangup.index ||
            callStartMessageContent.status == CallStartEndStatus.kWFAVCallEndReasonAllLeft.index) {
          if (model.message.direction == MessageDirection.MessageDirection_Send) {
            ext = "对方已拒绝";
          } else {
            ext = "对方已取消";
          }
        }
      }
    } else if (callStartMessageContent.status != CallStartEndStatus.kWFAVCallEndReasonUnknown.index) {
      ext = "未接通";
    }

    return Text(
      callStartMessageContent.audioOnly ? '[语音通话] $ext' : '[视频通话] $ext',
      overflow: TextOverflow.ellipsis,
      maxLines: 10,
      style: const TextStyle(fontSize: 16),
    );
  }
}
