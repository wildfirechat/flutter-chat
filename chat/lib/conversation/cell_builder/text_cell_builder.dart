import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/widgets/rich_text_message.dart';
import 'package:chat/pc/media_preview_window/media_preview_window_manager.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:characters/characters.dart';
import 'package:chat/widgets/animated_emoji.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../../ui_model/ui_message.dart';
import '../mm_preview_view.dart';
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
    final Widget child;
    if (textMessageContent.quoteInfo != null) {
      // 气泡要跟着内容自适应宽度:引用块不能写 width: double.infinity(那会把
      // 气泡撑满整行)。用 IntrinsicWidth 取正文和引用块里较宽的那个作为气泡宽度
      // (仍受外层 maxWidth 约束,超了正常换行),再用 stretch 让引用块补齐到同宽,
      // 避免正文长、引用短时下面的灰底块比正文窄一截。
      child = IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            selectableText(
                context,
                Text(
                  textMessageContent.text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                )),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                var messageUid = textMessageContent.quoteInfo!.messageUid;
                var message = await Imclient.getMessageByUid(messageUid);
                if (message != null) {
                  if (message.content is ImageMessageContent ||
                      message.content is VideoMessageContent) {
                    if (context.mounted) {
                      if (isDesktopShell) {
                        // 参考微信:引用的图片/视频在独立窗口中预览(单条,不翻页)
                        MediaPreviewWindowManager.instance.show(
                          mediaItems: [message],
                          defaultIndex: 0,
                        );
                      } else {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    MMPreviewView(
                              [message],
                              defaultIndex: 0,
                              pageToEnd: (fromIndex, tail) {},
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    var digest = await message.content.digest(message);
                    Fluttertoast.showToast(msg: digest);
                  }
                } else {
                  if (context.mounted) {
                    Fluttertoast.showToast(
                        msg: AppLocalizations.of(context)!.messageNotExist);
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.bubbleQuoted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${textMessageContent.quoteInfo!.userDisplayName ?? ''}: ${textMessageContent.quoteInfo!.messageDigest ?? ''}",
                  style: AppText.xs
                      .copyWith(color: context.colors.bubbleQuotedText),
                ),
              ),
            )
          ],
        ),
      );
    } else {
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
      child = selectableText(
        context,
        RichTextMessageWidget(
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
        ),
      );
    }

    if (isDesktopShell) {
      return LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - 60),
          child: child,
        ),
      );
    }
    return child;
  }
}
