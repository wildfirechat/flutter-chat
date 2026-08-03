import 'package:flutter/material.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/widgets/rich_text_message.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';

import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class TextCellBuilder extends PortraitCellBuilder {
  late TextMessageContent textMessageContent;

  TextCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    textMessageContent = model.message.content as TextMessageContent;
  }

  @override
  bool get hasBubbleTail => true;

  @override
  Widget buildMessageContent(BuildContext context) {
    // 被引用的消息不进气泡,由 PortraitCellBuilder 挂在气泡下面(见 quoted_message_line.dart),
    // 所以这里只管正文,气泡宽度也就只跟正文走。
    return constrainBubbleWidth(selectableText(context, _bodyText(context)));
  }

  Widget _bodyText(BuildContext context) {
    final text = textMessageContent.text.trim();
    final charList = text.characters;
    final bool isSingleEmoji =
        charList.length == 1 && kChatEmojis.contains(charList.first);

    final conversationViewModel =
        Provider.of<ConversationViewModel>(context, listen: false);
    final messageList = conversationViewModel.conversationMessageList;
    final bool isLastMessage = messageList.isNotEmpty &&
        messageList.first.message.messageId == model.message.messageId;

    final onSolidAccent =
        isSendMessage && Theme.of(context).brightness == Brightness.dark;
    return RichTextMessageWidget(
      text: textMessageContent.text,
      style: AppText.lg,
      linkStyle: AppText.lg.copyWith(
          color: onSolidAccent
              ? context.colors.bubbleSentText
              : context.colors.link,
          decoration: TextDecoration.underline),
      onLinkTap: (url) => Utilities.openLink(context, url),
      isSingleEmoji: isSingleEmoji && !isDesktopShell,
      isLastMessage: isLastMessage,
    );
  }
}
