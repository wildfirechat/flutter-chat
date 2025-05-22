import 'dart:async';
import 'dart:math';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:wfc_example/conversation/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class VoicePlayStatusChangedEvent {
  int messageId;
  bool start;

  VoicePlayStatusChangedEvent(this.messageId, this.start);
}

class VoiceCellBuilder extends PortraitCellBuilder {
  late SoundMessageContent soundMessageContent;
  late int messageId;
  bool _playing = false;
  late StreamSubscription<VoicePlayStatusChangedEvent> _playEventSubscription;

  Timer? _timer;
  int _voiceLevel = 0;
  final bool _notPlayed = false;

  VoiceCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    soundMessageContent = model.message.content as SoundMessageContent;
    messageId = model.message.messageId;
    // _playEventSubscription = _eventBus.on<VoicePlayStatusChangedEvent>().listen((event) {
    //   if(event.messageId == messageId) {
    //     if (_playing != event.start) {
    //       setState(() {
    //         _playing = event.start;
    //         if (_playing) {
    //           _startTimer();
    //         } else {
    //           _stopTimer();
    //         }
    //       });
    //     }
    //   }
    // });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // setState(() {
      //   _voiceLevel = (_voiceLevel+1)%3;
      // });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    String imagePaht = isSendMessage ? 'assets/images/send_voice.png' : 'assets/images/receive_voice.png';
    if (_playing) {
      imagePaht = isSendMessage ? 'assets/images/send_voice_$_voiceLevel.png' : 'assets/images/receive_voice_$_voiceLevel.png';
    }
    Image image = Image.asset(imagePaht, width: 20.0, height: 20.0);
    Text text = Text('${soundMessageContent.duration}"');
    double d = min(soundMessageContent.duration * 2 + 5, 120);
    Container paddingEnd = Container(
      width: d,
    );
    Container padding = Container(
      width: 5,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isSendMessage ? paddingEnd : padding,
        isSendMessage ? text : image,
        padding,
        isSendMessage ? image : text,
        isSendMessage ? padding : paddingEnd,
      ],
    );
  }

  // TODO
  // @override
  // void dispose() {
  //   super.dispose();
  //   _playEventSubscription.cancel();
  //   _stopTimer();
  // }
}
