import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/utilities.dart';
import 'cell_builder/call_start_cell_builder.dart';
import 'cell_builder/image_cell_builder.dart';
import 'cell_builder/message_cell_builder.dart';
import 'cell_builder/notification_cell_builder.dart';
import 'cell_builder/portrait_cell_builder.dart';
import 'cell_builder/text_cell_builder.dart';
import 'cell_builder/unknown_cell_builder.dart';
import 'message_model.dart';

class MessageCell extends StatefulWidget {
  final MessageModel model;

  MessageCell(this.model):super(key: ObjectKey(model));

  @override
  State createState() {
    return MessageState();
  }
}

class MessageState extends State<MessageCell> {
  late MessageCellBuilder _cellBuilder;
  @override
  void initState() {
    super.initState();
    if(widget.model.message.content is NotificationMessageContent) {
      _cellBuilder = NotificationCellBuilder(this, widget.model);
    } else if(widget.model.message.content is TextMessageContent) {
      _cellBuilder = TextCellBuilder(this, widget.model);
    } else if(widget.model.message.content is ImageMessageContent) {
      _cellBuilder = ImageCellBuilder(this, widget.model);
    } else if(widget.model.message.content is CallStartMessageContent) {
      _cellBuilder = CallStartCellBuilder(this, widget.model);
    } else {
      _cellBuilder = UnknownCellBuilder(this, widget.model);
    }
  }

  @override
  Widget build(BuildContext context) {
      return _cellBuilder.build(context);
  }

  void refreshAfter(VoidCallback callback) {
    setState(callback);
  }
}

