import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/utilities.dart';
import 'cell_builder/call_start_cell_builder.dart';
import 'cell_builder/card_cell_builder.dart';
import 'cell_builder/file_cell_builder.dart';
import 'cell_builder/image_cell_builder.dart';
import 'cell_builder/message_cell_builder.dart';
import 'cell_builder/notification_cell_builder.dart';
import 'cell_builder/portrait_cell_builder.dart';
import 'cell_builder/text_cell_builder.dart';
import 'cell_builder/unknown_cell_builder.dart';
import 'cell_builder/video_cell_builder.dart';
import 'cell_builder/voice_cell_builder.dart';
import 'message_model.dart';

typedef OnMessageCellTapedCallback = void Function(MessageModel model);
typedef OnMessageCellDoubleTapedCallback = void Function(MessageModel model);
typedef OnMessageCellLongPressedCallback = void Function(MessageModel model, Offset offset);
typedef OnPortraitTapedCallback = void Function(MessageModel model);
typedef OnPortraitLongTapedCallback = void Function(MessageModel model);
typedef OnResendTapedCallback = void Function(MessageModel model);
typedef OnReadedTapedCallback = void Function(MessageModel model);

class MessageCell extends StatefulWidget {
  final MessageModel model;
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

  void onTaped(MessageModel model) {
    widget.cellTapedCallback(model);
  }

  void onDoubleTaped(MessageModel model) {
    widget.cellDoubleTapedCallback(model);
  }

  void onLongPress(LongPressStartDetails details, MessageModel model) {
    widget.cellLongPressedCallback(model, details.globalPosition);
  }

  void onTapedPortrait(MessageModel model) {
    widget.portraitTapedCallback(model);
  }

  void onLongTapedPortrait(MessageModel model) {
    widget.portraitLongTapedCallback(model);
  }

  void onResendTaped(MessageModel model) {
    widget.resendTapedCallback(model);
  }

  void onReadedTaped(MessageModel model) {
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

