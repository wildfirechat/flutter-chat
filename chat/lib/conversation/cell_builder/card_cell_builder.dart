import 'package:flutter/material.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:chat/config.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/l10n/app_localizations.dart';

class CardCellBuilder extends PortraitCellBuilder {
  late CardMessageContent cardMessageContent;

  CardCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    cardMessageContent = model.message.content as CardMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dpr = MediaQuery.of(context).devicePixelRatio;

    final l10n = AppLocalizations.of(context)!;
    String imagePath = Config.defaultUserPortrait;
    String hint = l10n.personalCardHint;
    if (cardMessageContent.type == CardType.CardType_Group) {
      imagePath = Config.defaultGroupPortrait;
      hint = l10n.groupCardHint;
    } else if (cardMessageContent.type == CardType.CardType_Channel) {
      imagePath = Config.defaultChannelPortrait;
      hint = l10n.channelCardHint;
    }

    Image image = cardMessageContent.portrait != null
        ? Image.network(
            MediaUrlRedirector.redirect(cardMessageContent.portrait!),
            width: 48.0,
            height: 48.0,
            // 按显示尺寸×dpr 解码，避免原图全尺寸解码占用大量内存
            cacheWidth: (48 * dpr).ceil(),
            cacheHeight: (48 * dpr).ceil(),
          )
        : Image.asset(imagePath, width: 48.0, height: 48.0);
    Text displayNameText = Text(
      cardMessageContent.displayName!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.lg,
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
          const Divider(indent: 4, endIndent: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 0, 0),
            child: Text(
              hint,
              style: AppText.xs.copyWith(color: Colors.black26),
            ),
          ),
          padding,
        ],
      ),
    );
  }
}
