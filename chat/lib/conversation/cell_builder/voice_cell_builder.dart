import 'dart:async';
import 'dart:math';

import 'package:chat/utils/layout_scale.dart';

import 'package:chat/event_bus.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';

import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_typography.dart';

class VoicePlayStatusChangedEvent {
  int messageId;
  bool start;

  VoicePlayStatusChangedEvent(this.messageId, this.start);
}

class VoiceSpeechToTextUpdatedEvent {
  int messageId;

  VoiceSpeechToTextUpdatedEvent(this.messageId);
}

class VoiceCellBuilder extends PortraitCellBuilder {
  late SoundMessageContent soundMessageContent;
  late int messageId;
  bool _playing = false;
  StreamSubscription<VoicePlayStatusChangedEvent>? _playEventSubscription;
  StreamSubscription<VoiceSpeechToTextUpdatedEvent>? _speechToTextSubscription;

  Timer? _timer;
  int _voiceLevel = 0;

  VoiceCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    soundMessageContent = model.message.content as SoundMessageContent;
    messageId = model.message.messageId;
    _playEventSubscription =
        eventBus.on<VoicePlayStatusChangedEvent>().listen((event) {
      if (event.messageId == messageId) {
        if (_playing != event.start) {
          _playing = event.start;
          if (_playing) {
            _startTimer();
          } else {
            _stopTimer();
            _voiceLevel = 0;
          }
          setState(() {});
        }
      }
    });

    // 监听转文字更新事件
    _speechToTextSubscription =
        eventBus.on<VoiceSpeechToTextUpdatedEvent>().listen((event) {
      if (event.messageId == messageId) {
        setState(() {});
      }
    });
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _voiceLevel = (_voiceLevel + 1) % 3;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    String imagePath = isSendMessage
        ? 'assets/images/send_voice.png'
        : 'assets/images/receive_voice.png';
    if (_playing) {
      imagePath = isSendMessage
          ? 'assets/images/send_voice_$_voiceLevel.png'
          : 'assets/images/receive_voice_$_voiceLevel.png';
    }
    Image image = Image.asset(imagePath, width: 20.0, height: 20.0);
    Text text = Text('${soundMessageContent.duration}"');
    double d = min(soundMessageContent.duration * 2 + 5, 120);
    Container paddingEnd = Container(
      width: d,
    );
    Container padding = Container(
      width: 5,
    );

    // 构建语音气泡
    Widget voiceContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isSendMessage ? paddingEnd : padding,
        isSendMessage ? text : image,
        padding,
        isSendMessage ? image : text,
        isSendMessage ? padding : paddingEnd,
      ],
    );

    // 如果有转文字内容，在语音气泡下方显示
    if (soundMessageContent.speechText != null &&
        soundMessageContent.speechText!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          voiceContent,
          const SizedBox(height: 6),
          Text(
            soundMessageContent.speechText!,
            style: AppText.base.copyWith(color: Colors.black87),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // 如果正在转文字，显示进度
    if (soundMessageContent.speechToTextInProgress) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          voiceContent,
          const SizedBox(height: 6),
          SizedBox(
            // 12sp 的「转文字中」在最大档位下行高约 20.4px,固定 20 会溢出。
            height:
                LayoutScale.watchScale(context, 20.0, cap: LayoutScale.textCap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.convertingToText,
                  style: AppText.xs.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return voiceContent;
  }

  @override
  void dispose() {
    super.dispose();
    _playEventSubscription?.cancel();
    _speechToTextSubscription?.cancel();
    _stopTimer();
  }
}
