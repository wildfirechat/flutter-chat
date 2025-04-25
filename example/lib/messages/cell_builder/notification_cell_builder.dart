
import 'package:flutter/cupertino.dart';

import '../message_cell.dart';
import '../message_model.dart';
import 'message_cell_builder.dart';

class NotificationCellBuilder extends MessageCellBuilder {
  String digest = "";

  NotificationCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    model.message.content.digest(model.message).then((value) {
      setState(() {
        digest = value;
      });
    });
  }

  @override
  Widget getContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(60, 0, 60, 0),
      child: Text(digest, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12),),
    );
  }
}