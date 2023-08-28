import 'package:flutter/cupertino.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class CallStartCellBuilder extends PortraitCellBuilder {
  late CallStartMessageContent callStartMessageContent;

  CallStartCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    callStartMessageContent = model.message.content as CallStartMessageContent;
  }

  @override
  Widget getContentAres() {
    return Text(callStartMessageContent.audioOnly?'[语音通话]':'[视频通话]', overflow: TextOverflow.ellipsis, maxLines: 10, style: TextStyle(fontSize: 16),);
  }
}
