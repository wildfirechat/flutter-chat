import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:wfc_example/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:wfc_example/conversation/picture_overview.dart';
import 'package:wfc_example/conversation/video_player_view.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

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
            maxLines: 1000,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              var messageUid = textMessageContent.quoteInfo!.messageUid;
              var message = await Imclient.getMessageByUid(messageUid);
              if (message != null) {
                if (message.content is ImageMessageContent) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PictureOverview(
                          [message],
                          defaultIndex: 0,
                          pageToEnd: (fromIndex, tail) {},
                        ),
                      ),
                    );
                  }
                } else if (message.content is VideoMessageContent) {
                  var videoContent = message.content as VideoMessageContent;
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerView(videoContent.remoteUrl!),
                      ),
                    );
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
    return Text(
      textMessageContent.text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1000,
      style: const TextStyle(fontSize: 16),
    );
  }
}
