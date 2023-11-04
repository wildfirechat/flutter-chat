
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:rtckit/rtckit.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/imclient.dart';
import 'call_state_view.dart';

class SingleVideoCallView extends StatefulWidget {
  String? userId;
  bool? audioOnly;
  CallSession? callSession;
  SingleVideoCallView({this.callSession, this.userId, this.audioOnly=false, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SingleVideoCallState();
}

class SingleVideoCallState extends State<SingleVideoCallView> implements CallSessionCallback {
  final Color backgroundColor = Colors.blue;
  late Widget bigVideoView;
  late Widget smallVideoView;

  int? bigVideoViewId;
  int? smallVideoViewId;

  bool localVideoCreated = false;
  bool remoteVideoCreated = false;
  GlobalKey<CallStateViewState> stateGlobalKey = GlobalKey();

  UserInfo? userInfo;

  @override
  void initState() {
    if(widget.callSession == null) {
      if(widget.userId == null) {
        Navigator.pop(context);
        return;
      }

      if(!widget.audioOnly!) {
        createVideoView();
      } else {
        Imclient.getUserInfo(widget.userId!).then((value) {
          setState(() {
            userInfo = value;
          });
        });
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
      if(!widget.callSession!.audioOnly) {
        createVideoView();
      } else {
        Imclient.getUserInfo(widget.callSession!.inviter!).then((value) {
          setState(() {
            userInfo = value;
          });
        });
      }
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
    return Container(
      color: backgroundColor,
      child: Stack(
      children: [
        //底视图，如果是视频就是大的视频流，如果是音频就是背景颜色
        backgroundCallView(context),
        //预览图或头像，如果是视频通话，就是预览，如果是音频就是头像
        previewOrPortraitView(context),
        //控制视图，挂断静音等等
        controlView(context),
      ],
      ),
    );
  }

  Widget backgroundCallView(BuildContext context) {
    if(widget.callSession!.audioOnly) {
      return Container();
    } else {
      return Container(
        color: backgroundColor,
        child: bigVideoView,
      );
    }
  }

  Widget userPortraitAndName(BuildContext context) {
    if(userInfo != null) {
      return Center(
        heightFactor: 5,
        child: Column(
          mainAxisSize:MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0), // 设置圆角半径
              child: SizedBox(width: 100,
                height: 100,
                child: userInfo!.portrait == null
                    ? Image.asset(
                    Rtckit.defaultUserPortrait, width: 100.0, height: 100.0)
                    : Image.network(
                    userInfo!.portrait!, width: 100.0, height: 100.0),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8)),
            Center(child: Text(userInfo!.displayName!, style: const TextStyle(color: Colors.white),),)
          ],
        ),
      );
    } else {
      return Container();
    }
  }

  Widget previewOrPortraitView(BuildContext context) {
    if(widget.callSession!.audioOnly) {
      return userPortraitAndName(context);
    } else {
      if(widget.callSession!.state == kWFAVEngineStateIncoming) {
        return userPortraitAndName(context);
      } else if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        return userPortraitAndName(context);
      }
      return Positioned(top: 64,
        left: 16,
        child: SizedBox(width: 120, height: 180, child: smallVideoView),);
    }
  }

  Widget createNativeVideoView(BuildContext context, bool big) {
    const String viewType = '<platform-view-type>';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    if(defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          if (big) {
            bigVideoViewId = params.id;
          } else {
            smallVideoViewId = params.id;
          }
          updateVideoView();

          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () {
              params.onFocusChanged(true);
            },
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
        },
      );
    } else if(defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (viewId) {
          if (big) {
            bigVideoViewId = viewId;
          } else {
            smallVideoViewId = viewId;
          }
          updateVideoView();
        },
      );
    }

    return Container();
  }

  List<Widget> _controlRowBottom1(BuildContext context) {
    if(!widget.callSession!.audioOnly) {
      if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        return [];
      } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
        //1 downgrade to voice call
        return [_blankControl(context), _downgrade2VoiceControl(context)];
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
          child: const Image(image:AssetImage('assets/images/rtckit/call_answer.png', package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.answerCall(false);
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('接听', style: TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget _hangupControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Image(image:AssetImage('assets/images/rtckit/call_hangup.png', package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.endCall();
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('挂断', style: TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget _audioMuteControl(BuildContext context) {
    String path = widget.callSession!.audioMuted?'assets/images/rtckit/call_voice_mute_hover.png':'assets/images/rtckit/call_voice_mute.png';
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: Image(image:AssetImage(path, package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.muteAudio(!widget.callSession!.audioMuted);
            setState(() {

            });
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('麦克风', style: TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget _videoMuteControl(BuildContext context) {
    String path = widget.callSession!.videoMuted?'assets/images/rtckit/call_video_disable.png':'assets/images/rtckit/call_video_enable.png';
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: Image(image:AssetImage(path, package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.muteVideo(!widget.callSession!.videoMuted);
            setState(() {

            });
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('摄像头', style: TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget _switchCameraControl(BuildContext context) {
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const Image(image:AssetImage('assets/images/rtckit/call_camera_switch.png', package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.switchCamera();
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('翻转', style: TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget _speakerControl(BuildContext context) {
    String path = widget.callSession!.speaker?'assets/images/rtckit/call_speaker_hover.png':'assets/images/rtckit/call_speaker.png';
    return Expanded(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: Image(image:AssetImage(path, package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            widget.callSession!.enableSpeaker(!widget.callSession!.speaker);
            setState(() {

            });
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        const Text('扬声器', style: TextStyle(color: Colors.white),),
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
          child: const Image(image:AssetImage('assets/images/rtckit/call_to_voice.png', package: 'rtckit'), width: 48, height: 48,),
          onTap: () {
            if(widget.callSession!.state == kWFAVEngineStateIncoming) {
              widget.callSession!.answerCall(true);
              setState(() {

              });
            } else if(widget.callSession!.state == kWFAVEngineStateConnected) {
              widget.callSession!.changeToAudioOnly();
              setState(() {

              });
            }
          },
        ),
        const Padding(padding: EdgeInsets.only(top: 8)),
        Text(widget.callSession!.state == kWFAVEngineStateIncoming ? '语音接听' : '转为语音', style: const TextStyle(color: Colors.white),),
      ],
    ),);
  }

  Widget controlView(BuildContext context) {
    return Column(
      children: [
        const Row(children: [
          //"assets/images/conversation_msg_sending.png"
          Padding(padding: EdgeInsets.fromLTRB(24, 60, 0, 0), child: Image(image:AssetImage('assets/images/rtckit/call_minimize.png', package: 'rtckit'), width: 24, height: 24,),)
        ],),
        const Padding(padding: EdgeInsets.all(20)),
        Center(child: CallStateView(widget.callSession!.state, key: stateGlobalKey,),),
        Expanded(child: Container()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom1(context),
        ),
        const Padding(padding: EdgeInsets.all(20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom2(context),
        ),
        const Padding(padding: EdgeInsets.all(40))
      ],
    );
  }

  void updateVideoView() {
    if(!widget.callSession!.audioOnly) {
      if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
        if(localVideoCreated && bigVideoViewId != null) {
          widget.callSession!.setLocalVideoView(bigVideoViewId!);
        }
      } else {
        if(localVideoCreated && smallVideoViewId != null) {
          widget.callSession!.setLocalVideoView(smallVideoViewId!);
        }

        if(remoteVideoCreated && bigVideoViewId != null) {
          widget.callSession!.setRemoteVideoView(widget.userId!, false, bigVideoViewId!);
        }
      }
    }
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
    setState(() {

    });
  }

  @override
  void didChangeState(int state) {
    if(stateGlobalKey.currentState != null) {
      stateGlobalKey.currentState!.updateCallStateView(state);
    }
    updateVideoView();
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