import 'package:flutter/cupertino.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class TextCellBuilder extends PortraitCellBuilder {
  late TextMessageContent textMessageContent;

  TextCellBuilder(MessageCell cell, UIMessage model) : super(cell, model) {
    textMessageContent = model.message.content as TextMessageContent;
  }

  @override
  Widget getContentAres(BuildContext context) {
    return Text(
      textMessageContent.text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1000,
      style: const TextStyle(fontSize: 16),
    );
  }
}
