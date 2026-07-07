import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';

import '../../ui_model/ui_message.dart';
import '../mm_preview_view.dart';

class TextCellBuilder extends PortraitCellBuilder {
  late TextMessageContent textMessageContent;

  TextCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    textMessageContent = model.message.content as TextMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    if (textMessageContent.quoteInfo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Text(
            textMessageContent.text,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              var messageUid = textMessageContent.quoteInfo!.messageUid;
              var message = await Imclient.getMessageByUid(messageUid);
              if (message != null) {
                if (message.content is ImageMessageContent || message.content is VideoMessageContent) {
                  if (context.mounted) {
                    final preview = MMPreviewView(
                      [message],
                      defaultIndex: 0,
                      pageToEnd: (fromIndex, tail) {},
                    );
                    if (isDesktopShell) {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black,
                        useSafeArea: false,
                        builder: (_) => preview,
                      );
                    } else {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (context, animation, secondaryAnimation) => preview,
                        ),
                      );
                    }
                  }
                } else {
                  var digest = await message.content.digest(message);
                  Fluttertoast.showToast(msg: digest);
                }
              } else {
                Fluttertoast.showToast(msg: "消息不存在");
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${textMessageContent.quoteInfo!.userDisplayName ?? ''}: ${textMessageContent.quoteInfo!.messageDigest ?? ''}",
                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
            ),
          )
        ],
      );
    }
    return Linkify(
      onOpen: (link) => Utilities.openLink(context, link.url),
      text: textMessageContent.text,
      style: const TextStyle(fontSize: 16),
      linkStyle: const TextStyle(
        fontSize: 16,
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      options: const LinkifyOptions(
        humanize: false,
      ),
    );
  }

}
