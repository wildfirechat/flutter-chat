import 'package:flutter/material.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:chat/utilities.dart';

import '../../ui_model/ui_message.dart';

class StreamingTextCellBuilder extends PortraitCellBuilder {
  late String text;
  late bool isGenerating;

  StreamingTextCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    if (model.message.content is StreamingTextGeneratingMessageContent) {
      text = (model.message.content as StreamingTextGeneratingMessageContent).text;
      isGenerating = true;
    } else if (model.message.content is StreamingTextGeneratedMessageContent) {
      text = (model.message.content as StreamingTextGeneratedMessageContent).text;
      isGenerating = false;
    } else {
      text = "";
      isGenerating = false;
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Linkify(
              onOpen: (link) => Utilities.openLink(context, link.url),
              text: text,
              style: const TextStyle(fontSize: 16),
              linkStyle: const TextStyle(
                fontSize: 16,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              options: const LinkifyOptions(
                humanize: false,
              ),
            ),
            if (isGenerating)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }

}
