import 'package:flutter/material.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class CardCellBuilder extends PortraitCellBuilder {
  late CardMessageContent cardMessageContent;

  CardCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    cardMessageContent = model.message.content as CardMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    String imagePath = Config.defaultUserPortrait;
    String hint = "个人名片";
    if (cardMessageContent.type == CardType.CardType_Group) {
      imagePath = Config.defaultGroupPortrait;
      hint = "群组名片";
    } else if (cardMessageContent.type == CardType.CardType_Channel) {
      imagePath = Config.defaultChannelPortrait;
      hint = "频道名片";
    }

    Image image =
        cardMessageContent.portrait != null ? Image.network(cardMessageContent.portrait!, width: 48.0, height: 48.0) : Image.asset(imagePath, width: 48.0, height: 48.0);
    Text displayNameText = Text(
      cardMessageContent.displayName!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16),
    );
    SizedBox padding = const SizedBox(
      width: 3,
      height: 3,
    );
    return SizedBox(
      width: screenWidth / 2,
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
              Expanded(
                child: displayNameText,
              ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 0, 0),
            child: Text(
              hint,
              style: const TextStyle(fontSize: 11, color: Colors.black26),
            ),
          ),
          padding,
        ],
      ),
    );
  }
}
