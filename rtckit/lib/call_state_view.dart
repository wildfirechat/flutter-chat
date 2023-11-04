import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rtckit/rtckit.dart';

class CallStateView extends StatefulWidget {
  int state = 0;
  CallStateView(this.state, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CallStateViewState();
}

class CallStateViewState extends State<CallStateView> {
  String _stateText = "";
  Timer? _timer;
  int _startTime = 0;
  int dotCount = 0;


  void updateCallStateView(int state) {
    widget.state = state;
    if(state == kWFAVEngineStateConnected) {
      setCallStart();
    } else if(state == kWFAVEngineStateConnecting) {
      _stateText = '连接中';
    } else if(state == kWFAVEngineStateIdle) {
      setCallStoped();
      _stateText = '';
    } else if(state == kWFAVEngineStateIncoming) {
      _stateText = '邀请您通话';
    } else if(state == kWFAVEngineStateOutgoing) {
      _stateText = '等待对方接受邀请';
    }
  }

  @override
  void initState() {
    updateCallStateView(widget.state);

    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if(_startTime > 0) {
          Duration d = Duration(milliseconds: DateTime
              .now()
              .millisecondsSinceEpoch - _startTime);
          int hours = d.inHours;
          int minutes = d.inMinutes.remainder(60);
          int seconds = d.inSeconds.remainder(60);
          if (hours > 0) {
            _stateText =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(
                2, '0')}:${seconds.toString().padLeft(2, '0')}';
          } else {
            _stateText =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(
                2, '0')}';
          }
        } else {
          dotCount = (++dotCount)%4;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String text = _stateText;
    if(_startTime == 0) {
      for (int i = 0; i < dotCount; i++) {
        text = '$text.';
      }
      for (int j = 0; j < 4 - dotCount; j++) {
        text = '$text ';
      }
    }
    return Text(text, style: const TextStyle(color: Colors.white));
  }

  void setStateText(String text) {
    setState(() {
      _stateText = text;
    });
  }

  void setCallStoped() {
    if(_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void setCallStart() {
    if(_startTime == 0) {
      _startTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void dispose() {
    super.dispose();
    setCallStoped();
  }
}