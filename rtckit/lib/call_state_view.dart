import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rtckit/rtckit.dart';

class CallStateView extends StatefulWidget {
  int state = 0;
  CallSession session;
  CallStateView(this.state, this.session, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CallStateViewState();
}

class CallStateViewState extends State<CallStateView> {
  String _stateText = "";
  Timer? _timer;
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
      _stateText = '对方正在邀请您通话';
    } else if(state == kWFAVEngineStateOutgoing) {
      _stateText = '等待对方接受邀请';
    }
  }

  @override
  void initState() {
    super.initState();
    updateCallStateView(widget.state);

    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateUI();
    });
    _updateUI();
  }

  void _updateUI() {
    setState(() {
      if(widget.session.connectedTime != null && widget.session.connectedTime! > 0) {
        Duration d = Duration(milliseconds: DateTime
            .now()
            .millisecondsSinceEpoch - widget.session.connectedTime!);
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
  }

  @override
  Widget build(BuildContext context) {
    String text = _stateText;
    if(widget.session.connectedTime == null || widget.session.connectedTime == 0) {
      for (int i = 0; i < dotCount; i++) {
        text = '$text.';
      }
      for (int j = 0; j < 4 - dotCount; j++) {
        text = '$text ';
      }
    }
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.none));
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
  }

  @override
  void dispose() {
    super.dispose();
    setCallStoped();
  }
}