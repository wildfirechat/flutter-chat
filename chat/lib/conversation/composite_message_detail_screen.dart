import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/cell_builder/call_start_cell_builder.dart';
import 'package:chat/conversation/cell_builder/card_cell_builder.dart';
import 'package:chat/conversation/cell_builder/composite_cell_builder.dart';
import 'package:chat/conversation/cell_builder/file_cell_builder.dart';
import 'package:chat/conversation/cell_builder/image_cell_builder.dart';
import 'package:chat/conversation/cell_builder/message_cell_builder.dart';
import 'package:chat/conversation/cell_builder/notification_cell_builder.dart';
import 'package:chat/conversation/cell_builder/streaming_text_cell_builder.dart';
import 'package:chat/conversation/cell_builder/text_cell_builder.dart';
import 'package:chat/conversation/cell_builder/unknown_cell_builder.dart';
import 'package:chat/conversation/cell_builder/video_cell_builder.dart';
import 'package:chat/conversation/cell_builder/voice_cell_builder.dart';
import 'package:chat/ui_model/ui_message.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';

class CompositeMessageDetailScreen extends StatelessWidget {
  final CompositeMessageContent content;

  const CompositeMessageDetailScreen(this.content, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
      ),
      body: ListView.builder(
        itemCount: content.messages.length,
        itemBuilder: (context, index) {
          Message message = content.messages[index];
          bool showAvatar = true;
          if (index > 0) {
            Message prev = content.messages[index - 1];
            if (prev.fromUser == message.fromUser) {
              showAvatar = false;
            }
          }

          // Force direction to receive so it looks like left aligned
          message.direction = MessageDirection.MessageDirection_Receive;
          UIMessage uiMessage = UIMessage(message);
          uiMessage.showTimeLabel = true;

          return _buildMessageRow(context, uiMessage, showAvatar);
        },
      ),
    );
  }

  Widget _buildMessageRow(BuildContext context, UIMessage uiMessage, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showAvatar
              ? Selector<UserViewModel, UserInfo?>(
                  selector: (context, userViewModel) => userViewModel.getUserInfo(uiMessage.message.fromUser),
                  builder: (context, userInfo, child) {
                    return Portrait(
                      userInfo?.portrait ?? Config.defaultUserPortrait,
                      Config.defaultUserPortrait,
                      width: 44.0,
                      height: 44.0,
                      borderRadius: 6.0,
                    );
                  },
                )
              : const SizedBox(width: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Selector<UserViewModel, UserInfo?>(
                    selector: (context, userViewModel) => userViewModel.getUserInfo(uiMessage.message.fromUser),
                    builder: (context, userInfo, child) {
                      return Text(
                        userInfo?.getReadableName() ?? "<${uiMessage.message.fromUser}>",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildContent(context, uiMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UIMessage model) {
    MessageCellBuilder cellBuilder;
    if (model.message.content is NotificationMessageContent) {
      cellBuilder = NotificationCellBuilder(context, model);
    } else if (model.message.content is TextMessageContent) {
      cellBuilder = TextCellBuilder(context, model);
    } else if (model.message.content is ImageMessageContent) {
      cellBuilder = ImageCellBuilder(context, model);
    } else if (model.message.content is CallStartMessageContent) {
      cellBuilder = CallStartCellBuilder(context, model);
    } else if (model.message.content is SoundMessageContent) {
      cellBuilder = VoiceCellBuilder(context, model);
    } else if (model.message.content is FileMessageContent) {
      cellBuilder = FileCellBuilder(context, model);
    } else if (model.message.content is CardMessageContent) {
      cellBuilder = CardCellBuilder(context, model);
    } else if (model.message.content is VideoMessageContent) {
      cellBuilder = VideoCellBuilder(context, model);
    } else if (model.message.content is StreamingTextGeneratingMessageContent || model.message.content is StreamingTextGeneratedMessageContent) {
      cellBuilder = StreamingTextCellBuilder(context, model);
    } else if (model.message.content is CompositeMessageContent) {
      cellBuilder = CompositeCellBuilder(context, model);
    } else {
      cellBuilder = UnknownCellBuilder(context, model);
    }
    return cellBuilder.buildMessageContent(context);
  }
}
