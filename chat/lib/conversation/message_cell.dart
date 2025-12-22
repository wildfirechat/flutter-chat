import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'cell_builder/call_start_cell_builder.dart';
import 'cell_builder/card_cell_builder.dart';
import 'cell_builder/file_cell_builder.dart';
import 'cell_builder/image_cell_builder.dart';
import 'cell_builder/message_cell_builder.dart';
import 'cell_builder/notification_cell_builder.dart';
import 'cell_builder/streaming_text_cell_builder.dart';
import 'cell_builder/text_cell_builder.dart';
import 'cell_builder/unknown_cell_builder.dart';
import 'cell_builder/video_cell_builder.dart';
import 'cell_builder/voice_cell_builder.dart';
import 'cell_builder/sticker_cell_builder.dart';
import 'cell_builder/composite_cell_builder.dart';
import '../ui_model/ui_message.dart';

class MessageCell extends StatefulWidget {
  final UIMessage model;

  MessageCell(this.model) : super(key: ObjectKey(model));

  @override
  State<MessageCell> createState() => _MessageCellState();
}

class _MessageCellState extends State<MessageCell> with AutomaticKeepAliveClientMixin {
  late MessageCellBuilder _cellBuilder;

  @override
  void initState() {
    super.initState();
    _initCellBuilder();
  }

  void _initCellBuilder() {
    if (widget.model.message.content is NotificationMessageContent) {
      _cellBuilder = NotificationCellBuilder(context, widget.model);
    } else if (widget.model.message.content is TextMessageContent) {
      _cellBuilder = TextCellBuilder(context, widget.model);
    } else if (widget.model.message.content is ImageMessageContent) {
      _cellBuilder = ImageCellBuilder(context, widget.model);
    } else if (widget.model.message.content is StickerMessageContent) {
      _cellBuilder = StickerCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CallStartMessageContent) {
      _cellBuilder = CallStartCellBuilder(context, widget.model);
    } else if (widget.model.message.content is SoundMessageContent) {
      _cellBuilder = VoiceCellBuilder(context, widget.model);
    } else if (widget.model.message.content is FileMessageContent) {
      _cellBuilder = FileCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CardMessageContent) {
      _cellBuilder = CardCellBuilder(context, widget.model);
    } else if (widget.model.message.content is VideoMessageContent) {
      _cellBuilder = VideoCellBuilder(context, widget.model);
    } else if (widget.model.message.content is StreamingTextGeneratingMessageContent || widget.model.message.content is StreamingTextGeneratedMessageContent) {
      _cellBuilder = StreamingTextCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CompositeMessageContent) {
      _cellBuilder = CompositeCellBuilder(context, widget.model);
    } else {
      _cellBuilder = UnknownCellBuilder(context, widget.model);
    }
    _cellBuilder.initState(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _cellBuilder.build(context);
  }

  @override
  void dispose() {
    super.dispose();
    _cellBuilder.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
