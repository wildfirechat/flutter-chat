import 'dart:async';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/conversation/input_bar/message_input_bar.dart';

import '../conversation_controller.dart';

class RecordWidget extends StatefulWidget {
  RecordWidget(this.conversation, {super.key});
  Conversation conversation;

  @override
  State<StatefulWidget> createState() => RecordState();
}

class RecordState extends State<RecordWidget> {
  FlutterSoundRecorder? _recorder;
  StreamSubscription? _recorderSubscription;
  StreamSubscription<double>? dbPeakSubscription;
  bool _isRecording = false;
  bool _isReleaseCancel = false;
  int _recordStartTime = 0;
  int _audioLevel = 1;

  OverlayEntry? overlayEntry;
  String voiceIcon = "images/voice_volume_1.png";
  double volume = 0.1;
  String soundTipsText = "手指上滑，取消发送";
  String soundTitleText = "松开发送";

  late ConversationController conversationController;

  @override
  Widget build(BuildContext context) {
    conversationController = Provider.of<ConversationController>(context, listen: false);
    OutlinedButton btn;
    if (_isRecording) {
      btn = OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: _isReleaseCancel ? Colors.red : Colors.green,
          ),
          onPressed: () {},
          child: Text(soundTitleText));
    } else {
      btn = OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.grey,
          ),
          onPressed: () {},
          child: const Text("按下说话"));
    }

    return GestureDetector(
      child: btn,
      onLongPressDown: (details) => _onVoiceLongPressDown(),
      onLongPressStart: (details) => _onVoiceLongPressStart(context),
      onLongPressUp: () => _onVoiceLongPressUp(),
      onLongPressCancel: () => _onVoiceLongPressCancel(),
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) => _onVoicePressMove(details),
    );
  }

  String? _recordPath;

  void _startRecord(BuildContext context) async {
    var status = Permission.byValue(Permission.microphone.value).request();
    if (!await status.isGranted && !await status.isLimited) {
      Fluttertoast.showToast(msg: "没有权限，请开启权限!");
      return;
    }

    var direction = await getTemporaryDirectory();
    _recordPath = '${direction.path}/record-${DateTime.now().millisecondsSinceEpoch}.wav';
    setState(() {
      _isRecording = true;
    });
    _recorder = FlutterSoundRecorder(logLevel: Level.wtf);
    await _recorder!.openRecorder();
    if (_isRecording) {
      await _recorder!.startRecorder(
        codec: Codec.pcm16WAV,
        sampleRate: 8000,
        numChannels: 1,
        toFile: _recordPath,
      );
      _recordStartTime = DateTime.now().millisecondsSinceEpoch;
      _recorder?.setSubscriptionDuration(const Duration(milliseconds: 250));
      _recorderSubscription = _recorder!.onProgress?.listen((RecordingDisposition event) {
        if (event.decibels != null) {
          _audioLevel = event.decibels! ~/ 16;
          if (_audioLevel > 6) {
            _audioLevel = 6;
          }
          if (overlayEntry != null) {
            overlayEntry!.markNeedsBuild();
          }
        }
      });
      buildOverLayView(context);
    }
  }

  void _stopRecord(bool send) {
    if (_recorder == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    } else {
      _isRecording = false;
    }
    if (_recorder != null) {
      _recorder!.stopRecorder().then((value) {
        if (send && !_isReleaseCancel) {
          int duration = (DateTime.now().millisecondsSinceEpoch - _recordStartTime + 500) ~/ 1000;
          conversationController.onSoundRecorded(widget.conversation, _recordPath!, duration);
        }
        _recorder = null;
      });
      _recorderSubscription?.cancel();
      _recorderSubscription = null;
    }

    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  buildOverLayView(BuildContext context) {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        return Positioned(
          top: 0,
          left: 0,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Material(
            color: Colors.transparent,
            type: MaterialType.canvas,
            child: Center(
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xff77797A),
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 50,
                              height: 60,
                              child: Image.asset(
                                "assets/images/input/voice/voice_${_audioLevel + 1}.png",
                                width: 50,
                                height: 60,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Text(
                        soundTipsText,
                        style: const TextStyle(
                          fontStyle: FontStyle.normal,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
      Overlay.of(context).insert(overlayEntry!);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _stopRecord(false);
  }

  void _onVoiceLongPressDown() {}

  void _onVoiceLongPressStart(BuildContext context) {
    _startRecord(context);
  }

  void _onVoiceLongPressUp() {
    _stopRecord(true);
  }

  void _onVoiceLongPressCancel() {
    _stopRecord(false);
  }

  void _onVoicePressMove(LongPressMoveUpdateDetails details) {
    double height = 25;
    double dy = details.localPosition.dy - 25;
    if (dy.abs() > height) {
      if (mounted && soundTipsText != "松开取消") {
        setState(() {
          soundTipsText = "松开取消";
          soundTitleText = "松开取消";
          _isReleaseCancel = true;
        });
      }
    } else {
      if (mounted && soundTipsText == "松开取消") {
        setState(() {
          soundTipsText = "手指上滑，取消发送";
          soundTitleText = "松开发送";
          _isReleaseCancel = false;
        });
      }
    }
  }
}
