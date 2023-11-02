
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:rtckit/rtckit.dart';

class SingleVideoCallView extends StatefulWidget {
  String? userId;
  bool? audioOnly;
  CallSession? callSession;
  SingleVideoCallView({this.callSession, this.userId, this.audioOnly=false, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SingleVideoCallState();
}

class SingleVideoCallState extends State<SingleVideoCallView> implements CallSessionCallback {
  late Widget bigVideoView;
  late Widget smallVideoView;

  int? bigVideoViewId;
  int? smallVideoViewId;

  bool localVideoCreated = false;
  bool remoteVideoCreated = false;

  @override
  void initState() {
    if(widget.callSession == null) {
      if(widget.userId == null) {
        Navigator.pop(context);
        return;
      }

      if(!widget.audioOnly!) {
        createVideoView();
      }
      Rtckit.startSingleCall(widget.userId!, widget.audioOnly!).then((value) {
        if (value == null) {
          Navigator.pop(context);
        } else {
          setState(() {
            widget.callSession = value;
            widget.callSession?.setCallSessionCallback(this);
            widget.callSession?.startPreview();
          });
        }
      });
    } else {
      widget.userId = widget.callSession?.conversation!.target;
      createVideoView();
      widget.callSession?.setCallSessionCallback(this);
    }
  }

  void createVideoView() {
    bigVideoView = createNativeVideoView(context, true);
    smallVideoView = createNativeVideoView(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.callSession == null?const Center(child: Text("Loading...")):callView(context),
    );
  }

  Widget callView(BuildContext context) {
    return Stack(
      children: [
        //底视图，如果是视频就是大的视频流，如果是音频就是背景颜色
        backgroundCallView(context),
        //预览图或头像，如果是视频通话，就是预览，如果是音频就是头像
        previewOrPortraitView(context),
        //控制视图，挂断静音等等
        controlView(context),
      ],
    );
  }

  Widget backgroundCallView(BuildContext context) {
    if(widget.callSession!.audioOnly) {
      return Container();
    } else {
      return bigVideoView;
    }
  }

  Widget previewOrPortraitView(BuildContext context) {
    if(widget.callSession!.audioOnly) {
      return Container();
    } else {
      return Positioned(top: 64,
        left: 16,
        child: SizedBox(width: 120, height: 180, child: smallVideoView),);
    }
  }

  Widget createNativeVideoView(BuildContext context, bool big) {
    const String viewType = '<platform-view-type>';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (viewId) {
        if(big) {
          bigVideoViewId = viewId;
        } else {
          smallVideoViewId = viewId;
        }
        updateVideoView();
      },
    );
  }

  List<Widget> _controlRowBottom1(BuildContext context) {
    if(!widget.callSession!.audioOnly) {
      if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        return [];
      } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
        //1 downgrade to voice call
        return [_blankControl(context), _blankControl(context), _downgrade2VoiceControl(context)];
      } else {
        //1 downgrade to voice call
        return [_switchCameraControl(context), _blankControl(context), _downgrade2VoiceControl(context)];
      }
    }
    return [];
  }

  List<Widget> _controlRowBottom2(BuildContext context) {
    if(widget.callSession!.audioOnly) {
      if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        //3 button, mic, hangup, speaker
        return [_audioMuteControl(context), _hangupControl(context), _speakerControl(context)];
      } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
        //2 button, hangup, accept
        return [_hangupControl(context), _acceptControl(context)];
      } else {
        //3 mic, hangup, speaker
        return [_audioMuteControl(context), _hangupControl(context), _speakerControl(context)];
      }
    } else {
      if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        //3 button, mic, hangup, switch camera
        return [_audioMuteControl(context), _hangupControl(context), _switchCameraControl(context)];
      } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
        //2 button, hangup， accept
        return [_hangupControl(context), _acceptControl(context)];
      } else {
        //3 mic, hangup, switch camera
        return [_audioMuteControl(context), _hangupControl(context), _videoMuteControl(context)];
      }
    }
  }

  Widget _acceptControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.call_rounded),
          onTap: () {
            widget.callSession!.answerCall(false);
          },
        ),
        const Text('接听'),
      ],
    ),);
  }

  Widget _hangupControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.call_end_rounded),
          onTap: () {
            widget.callSession!.endCall();
          },
        ),
        const Text('挂断'),
      ],
    ),);
  }

  Widget _audioMuteControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.mic_none_rounded),
          onTap: () {
            widget.callSession!.muteAudio(!widget.callSession!.audioMuted);
            setState(() {

            });
          },
        ),
        const Text('麦克风'),
      ],
    ),);
  }

  Widget _videoMuteControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.camera_alt_rounded),
          onTap: () {
            widget.callSession!.muteVideo(!widget.callSession!.videoMuted);
            setState(() {

            });
          },
        ),
        const Text('麦克风'),
      ],
    ),);
  }

  Widget _switchCameraControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.camera_alt_rounded),
          onTap: () {
            widget.callSession!.switchCamera();
          },
        ),
        const Text('翻转'),
      ],
    ),);
  }

  Widget _speakerControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.volume_mute_rounded),
          onTap: () {
            widget.callSession!.enableSpeaker(!widget.callSession!.speaker);
            setState(() {

            });
          },
        ),
        const Text('扬声器'),
      ],
    ),);
  }

  Widget _blankControl(BuildContext context) {
    return Expanded(child: Container(),);
  }

  Widget _downgrade2VoiceControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Icon(Icons.switch_access_shortcut_rounded),
          onTap: () {

          },
        ),
        const Text('转为语音'),
      ],
    ),);
  }

  Widget controlView(BuildContext context) {
    return Column(
      children: [
        const Padding(padding: EdgeInsets.all(20)),
        const Stack(
          children: [
            Padding(padding: EdgeInsets.fromLTRB(20, 0, 0, 0), child: Icon(Icons.close_fullscreen_rounded),),
            Center(child: Text("time..."),),
          ],
        ),
        Expanded(child: Container()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom1(context),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom2(context),
        ),
        const Padding(padding: EdgeInsets.all(40))
      ],
    );
  }

  void updateVideoView() {
    setState(() {
      if(localVideoCreated && smallVideoViewId != null) {
        widget.callSession!.setLocalVideoView(smallVideoViewId!);
      }

      if(remoteVideoCreated && bigVideoViewId != null) {
        widget.callSession!.setRemoteVideoView(widget.userId!, false, bigVideoViewId!);
      }
    });
  }

  @override
  void didCallEndWithReason(int reason) {
    Navigator.pop(context);
  }

  @override
  void didChangeInitiator(String initiator) {
    // TODO: implement didChangeInitiator
  }

  @override
  void didChangeMode(bool isAudioOnly) {
    // TODO: implement didChangeMode
  }

  @override
  void didChangeState(int state) {
    setState(() {

    });
  }

  @override
  void didCreateLocalVideoTrack() {
    localVideoCreated = true;
    updateVideoView();
  }

  @override
  void didError(String error) {
    // TODO: implement didError
  }

  @override
  void didGetStats() {
    // TODO: implement didGetStats
  }

  @override
  void didParticipantConnected(String userId, bool screenSharing) {
    // TODO: implement didParticipantConnected
  }

  @override
  void didParticipantJoined(String userId, bool screenSharing) {
    // TODO: implement didParticipantJoined
  }

  @override
  void didParticipantLeft(String userId, bool screenSharing, int reason) {
    // TODO: implement didParticipantLeft
  }

  @override
  void didReceiveRemoteVideoTrack(String userId, bool screenSharing) {
    remoteVideoCreated = true;
    updateVideoView();
  }

  @override
  void didVideoMuted(String userId, bool videoMuted) {
    // TODO: implement didVideoMuted
  }

  @override
  void didChangeAudioRoute() {
    // TODO: implement didChangeAudioRoute
  }

  @override
  void didChangeType(String userId, bool audience) {
    // TODO: implement didChangeType
  }

  @override
  void didMediaLost(String media, int lostPackage, bool screenSharing) {
    // TODO: implement didMediaLost
  }

  @override
  void didMuteStateChanged(List<String> userIds) {
    // TODO: implement didMuteStateChanged
  }

  @override
  void didRemoteMediaLost(String userId, String media, bool uplink, int lostPackage, bool screenSharing) {
    // TODO: implement didRemoteMediaLost
  }

  @override
  void didReportAudioVolume(String userId, int volume) {
    // TODO: implement didReportAudioVolume
  }

  @override
  void onScreenSharingFailure() {
    // TODO: implement onScreenSharingFailure
  }
}