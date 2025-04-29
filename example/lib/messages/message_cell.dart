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
import 'ui_message.dart';

typedef OnMessageCellTapedCallback = void Function(UIMessage model);
typedef OnMessageCellDoubleTapedCallback = void Function(UIMessage model);
typedef OnMessageCellLongPressedCallback = void Function(UIMessage model, Offset offset);
typedef OnPortraitTapedCallback = void Function(UIMessage model);
typedef OnPortraitLongTapedCallback = void Function(UIMessage model);
typedef OnResendTapedCallback = void Function(UIMessage model);
typedef OnReadedTapedCallback = void Function(UIMessage model);

class MessageCell extends StatefulWidget {
  final UIMessage model;
  OnMessageCellTapedCallback cellTapedCallback;
  OnMessageCellDoubleTapedCallback cellDoubleTapedCallback;
  OnMessageCellLongPressedCallback cellLongPressedCallback;
  OnPortraitTapedCallback portraitTapedCallback;
  OnPortraitLongTapedCallback portraitLongTapedCallback;
  OnResendTapedCallback resendTapedCallback;
  OnReadedTapedCallback readedTapedCallback;

  MessageCell(this.model, this.cellTapedCallback, this.cellDoubleTapedCallback, this.cellLongPressedCallback, this.portraitTapedCallback, this.portraitLongTapedCallback, this.resendTapedCallback, this.readedTapedCallback):super(key: ObjectKey(model));

  @override
  State createState() {
    return MessageState();
  }
}

class MessageState extends State<MessageCell> {
  final EventBus _eventBus = Imclient.IMEventBus;
  late MessageCellBuilder _cellBuilder;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<MessageUpdatedEvent> _updateMessageSubscription;
  bool disposed = false;
  @override
  void initState() {
    super.initState();
    _initCellBuilder();

    _recallMessageSubscription = _eventBus.on<RecallMessageEvent>().listen((event) {
      if(widget.model.message.messageUid == event.messageUid) {
        Imclient.getMessageByUid(event.messageUid).then((newMsg) {
          if(newMsg != null) {
            setState(() {
              widget.model.message = newMsg;
              _initCellBuilder();
            });
          }
        });
      }
    });
    _updateMessageSubscription = _eventBus.on<MessageUpdatedEvent>().listen((event) {
      if(widget.model.message.messageId == event.messageId) {
        Imclient.getMessage(event.messageId).then((msg) {
          if (msg != null) {
            setState(() {
              widget.model.message = msg;
              _initCellBuilder();
            });
          }
        });
      }
    });
  }

  void _initCellBuilder() {
    if(widget.model.message.content is NotificationMessageContent) {
      _cellBuilder = NotificationCellBuilder(this, widget.model);
    } else if(widget.model.message.content is TextMessageContent) {
      _cellBuilder = TextCellBuilder(this, widget.model);
    } else if(widget.model.message.content is ImageMessageContent) {
      _cellBuilder = ImageCellBuilder(this, widget.model);
    } else if(widget.model.message.content is CallStartMessageContent) {
      _cellBuilder = CallStartCellBuilder(this, widget.model);
    } else if(widget.model.message.content is SoundMessageContent) {
      _cellBuilder = VoiceCellBuilder(this, widget.model);
    } else if(widget.model.message.content is FileMessageContent) {
      _cellBuilder = FileCellBuilder(this, widget.model);
    } else if(widget.model.message.content is CardMessageContent) {
      _cellBuilder = CardCellBuilder(this, widget.model);
    } else if(widget.model.message.content is VideoMessageContent) {
      _cellBuilder = VideoCellBuilder(this, widget.model);
    } else {
      _cellBuilder = UnknownCellBuilder(this, widget.model);
    }
  }


  @override
  void dispose() {
    super.dispose();
    disposed = true;
    _recallMessageSubscription.cancel();
    _updateMessageSubscription.cancel();
    _cellBuilder.dispose();
  }

  void onTaped(UIMessage model) {
    widget.cellTapedCallback(model);
  }

  void onDoubleTaped(UIMessage model) {
    widget.cellDoubleTapedCallback(model);
  }

  void onLongPress(LongPressStartDetails details, UIMessage model) {
    widget.cellLongPressedCallback(model, details.globalPosition);
  }

  void onTapedPortrait(UIMessage model) {
    widget.portraitTapedCallback(model);
  }

  void onLongTapedPortrait(UIMessage model) {
    widget.portraitLongTapedCallback(model);
  }

  void onResendTaped(UIMessage model) {
    widget.resendTapedCallback(model);
  }

  void onReadedTaped(UIMessage model) {
    widget.readedTapedCallback(model);
  }

  @override
  Widget build(BuildContext context) {
      return _cellBuilder.build(context);
  }

  void refreshAfter(VoidCallback callback) {
    if(!disposed) {
      setState(callback);
    }
  }
}

