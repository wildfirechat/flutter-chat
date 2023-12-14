
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class CardCellBuilder extends PortraitCellBuilder {
  late CardMessageContent cardMessageContent;

  CardCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    cardMessageContent = model.message.content as CardMessageContent;
  }

  @override
  Widget getContentAres(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    String imagePaht = Config.defaultUserPortrait;
    String hint = "个人名片";
    if(cardMessageContent.type == CardType.CardType_Group) {
      imagePaht = Config.defaultGroupPortrait;
      hint = "群组名片";
    } else if(cardMessageContent.type == CardType.CardType_Channel) {
      imagePaht = Config.defaultChannelPortrait;
      hint = "频道名片";
    }

    Image image = cardMessageContent.portrait != null ? Image.network(cardMessageContent.portrait!, width: 48.0, height: 48.0) : Image.asset(imagePaht, width: 48.0, height: 48.0);
    Text displayNameText = Text(cardMessageContent.displayName!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16),);
    SizedBox padding = const SizedBox(width: 3, height: 3,);
    return SizedBox(
      width: screenWidth/2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              padding,
              padding,
              padding,
              Expanded(child: displayNameText,),
              padding,
              padding,
              padding,
            ],
          ),
          padding,
          padding,
          padding,
          Container(
            margin: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 5, 0, 0), child: Text(hint, style: const TextStyle(fontSize: 11, color: Colors.black26),),),
          padding,
        ],
      ),
    );
  }
}
