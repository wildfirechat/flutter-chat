import 'package:flutter/material.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:chat/utilities.dart';

import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_typography.dart';

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
            // 流式生成期间每个 token 到达都会触发 rebuild,此时用普通 Text 展示,
            // 避免 Linkify 反复全文正则解析;生成结束后才启用 Linkify 识别链接
            selectableText(
              context,
              isGenerating
                  ? Text(
                      text,
                      style: AppText.lg,
                    )
                  : Linkify(
                      onOpen: (link) => Utilities.openLink(context, link.url),
                      text: text,
                      style: AppText.lg,
                      linkStyle: AppText.lg.copyWith(color: Colors.blue, decoration: TextDecoration.underline),
                      options: const LinkifyOptions(
                        humanize: false,
                      ),
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
