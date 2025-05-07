
import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:provider/provider.dart';
import 'cell_builder/call_start_cell_builder.dart';
import 'cell_builder/card_cell_builder.dart';
import 'cell_builder/file_cell_builder.dart';
import 'cell_builder/image_cell_builder.dart';
import 'cell_builder/message_cell_builder.dart';
import 'cell_builder/notification_cell_builder.dart';
import 'cell_builder/text_cell_builder.dart';
import 'cell_builder/unknown_cell_builder.dart';
import 'cell_builder/video_cell_builder.dart';
import 'cell_builder/voice_cell_builder.dart';
import '../ui_model/ui_message.dart';
import 'conversation_notifier.dart';

class MessageCell extends StatelessWidget {
  final UIMessage model;
  late BuildContext context;
  late MessageCellBuilder _cellBuilder;
  late ConversationNotifier conversationNotifier;

  MessageCell(this.context, this.model) : super(key: ObjectKey(model)) {
    conversationNotifier = Provider.of<ConversationNotifier>(context, listen: false);
    _initCellBuilder();
  }

  void _initCellBuilder() {
    if (model.message.content is NotificationMessageContent) {
      _cellBuilder = NotificationCellBuilder(model);
    } else if (model.message.content is TextMessageContent) {
      _cellBuilder = TextCellBuilder(this, model);
    } else if (model.message.content is ImageMessageContent) {
      _cellBuilder = ImageCellBuilder(this, model);
    } else if (model.message.content is CallStartMessageContent) {
      _cellBuilder = CallStartCellBuilder(this, model);
    } else if (model.message.content is SoundMessageContent) {
      _cellBuilder = VoiceCellBuilder(this, model);
    } else if (model.message.content is FileMessageContent) {
      _cellBuilder = FileCellBuilder(this, model);
    } else if (model.message.content is CardMessageContent) {
      _cellBuilder = CardCellBuilder(this, model);
    } else if (model.message.content is VideoMessageContent) {
      _cellBuilder = VideoCellBuilder(this, model);
    } else {
      _cellBuilder = UnknownCellBuilder(this, model);
    }
  }

  void onTaped(UIMessage model) {
    conversationNotifier.onTapedCell(context, model);
  }

  void onDoubleTaped(UIMessage model) {
    conversationNotifier.onDoubleTapedCell(model);
  }

  void onLongPress(LongPressStartDetails details, UIMessage model) {
    conversationNotifier.onLongPressedCell(context, model, details.globalPosition);
  }

  void onTapedPortrait(UIMessage model) {
    conversationNotifier.onPortraitTaped(context, model);
  }

  void onLongTapedPortrait(UIMessage model) {
    conversationNotifier.onPortraitLongTaped(model);
  }

  void onResendTaped(UIMessage model) {
    conversationNotifier.onResendTaped(model);
  }

  void onReadedTaped(UIMessage model) {
    conversationNotifier.onReadedTaped(model);
  }

  @override
  Widget build(BuildContext context) {
    return _cellBuilder.build(context);
  }
}
