import 'package:flutter/cupertino.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class ImageCellBuilder extends PortraitCellBuilder {
  late ImageMessageContent imageMessageContent;

  ImageCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    imageMessageContent = model.message.content as ImageMessageContent;
  }

  @override
  Widget getContentAres() {
    if(imageMessageContent.remoteUrl != null) {
      return Image.network(imageMessageContent.remoteUrl!);
    } else {
      return Container();
    }
  }
}
