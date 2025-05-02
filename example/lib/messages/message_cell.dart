import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
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

typedef OnMessageCellTapedCallback = void Function(UIMessage model);
typedef OnMessageCellDoubleTapedCallback = void Function(UIMessage model);
typedef OnMessageCellLongPressedCallback = void Function(UIMessage model, Offset offset);
typedef OnPortraitTapedCallback = void Function(UIMessage model);
typedef OnPortraitLongTapedCallback = void Function(UIMessage model);
typedef OnResendTapedCallback = void Function(UIMessage model);
typedef OnReadedTapedCallback = void Function(UIMessage model);

class MessageCell extends StatelessWidget {
  final UIMessage model;
  late MessageCellBuilder _cellBuilder;
  OnMessageCellTapedCallback cellTapedCallback;
  OnMessageCellDoubleTapedCallback cellDoubleTapedCallback;
  OnMessageCellLongPressedCallback cellLongPressedCallback;
  OnPortraitTapedCallback portraitTapedCallback;
  OnPortraitLongTapedCallback portraitLongTapedCallback;
  OnResendTapedCallback resendTapedCallback;
  OnReadedTapedCallback readedTapedCallback;

  MessageCell(this.model, this.cellTapedCallback, this.cellDoubleTapedCallback, this.cellLongPressedCallback, this.portraitTapedCallback, this.portraitLongTapedCallback,
      this.resendTapedCallback, this.readedTapedCallback)
      : super(key: ObjectKey(model)) {
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
    cellTapedCallback(model);
  }

  void onDoubleTaped(UIMessage model) {
    cellDoubleTapedCallback(model);
  }

  void onLongPress(LongPressStartDetails details, UIMessage model) {
    cellLongPressedCallback(model, details.globalPosition);
  }

  void onTapedPortrait(UIMessage model) {
    portraitTapedCallback(model);
  }

  void onLongTapedPortrait(UIMessage model) {
    portraitLongTapedCallback(model);
  }

  void onResendTaped(UIMessage model) {
    resendTapedCallback(model);
  }

  void onReadedTaped(UIMessage model) {
    readedTapedCallback(model);
  }

  @override
  Widget build(BuildContext context) {
    return _cellBuilder.build(context);
  }
}
