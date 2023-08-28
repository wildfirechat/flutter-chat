import 'package:flutter/cupertino.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class TextCellBuilder extends PortraitCellBuilder {
  late TextMessageContent textMessageContent;

  TextCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    textMessageContent = model.message.content as TextMessageContent;
  }

  @override
  Widget getContentAres() {
    return Text(textMessageContent.text, overflow: TextOverflow.ellipsis, maxLines: 1000, style: const TextStyle(fontSize: 16),);
  }
}
