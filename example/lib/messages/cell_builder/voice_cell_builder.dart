import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class VoiceCellBuilder extends PortraitCellBuilder {
  late SoundMessageContent soundMessageContent;

  VoiceCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    soundMessageContent = model.message.content as SoundMessageContent;
  }

  @override
  Widget getContentAres(BuildContext context) {
    String imagePaht = isSendMessage ? 'assets/images/send_voice.png' : 'assets/images/receive_voice.png';
    Image image = Image.asset(imagePaht, width: 20.0, height: 20.0);
    Text text = Text('${soundMessageContent.duration}"');
    double d = min(soundMessageContent.duration*2 + 5, 120);
    Container paddingEnd = Container(width: d,);
    Container padding = Container(width: 5,);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isSendMessage?paddingEnd:padding,
        isSendMessage?text:image,
        padding,
        isSendMessage?image:text,
        isSendMessage?padding:paddingEnd,
      ],
    );
  }
}
