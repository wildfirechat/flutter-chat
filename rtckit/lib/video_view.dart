import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:rtckit/rtckit.dart';

class VideoView extends StatefulWidget {
  CallSession callSession;
  ParticipantProfile profile;

  VideoView(this.callSession, this.profile, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => VideoViewState();
}

class VideoViewState extends State<VideoView> {
  late Widget rtcView;
  int? rtcViewId;
  UserInfo? userInfo;
  Timer? _timer;
  int dotPos = 0;
  List<Widget> waitAnis = [];

  @override
  void initState() {
    super.initState();
    rtcView = _createNativeVideoView(context, widget.profile.userId);

    String? groupId;
    if(widget.callSession.conversation != null && widget.callSession!.conversation!.conversationType == ConversationType.Group) {
      groupId = widget.callSession.conversation!.target;
    }
    Imclient.getUserInfo(widget.profile.userId, groupId: groupId).then((value) {
      setState(() {
        userInfo = value;
      });
    });

    for(int i = 0; i < 3; i++) {
      waitAnis.add(Image(image:AssetImage('assets/images/rtckit/call_waiting_ani$i.png', package: 'rtckit'), width: 50, height: 50,));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _callView(context),
        _stateView(context),
        (widget.profile.userId == Imclient.currentUserId && widget.profile.audioMuted)?  const Positioned(
            bottom: 8,
            left: 8,
            child: Image(image:AssetImage('assets/images/rtckit/call_voice_mute_small.png', package: 'rtckit'), width: 24, height: 24,)) : Container(),
        (widget.profile.userId == Imclient.currentUserId && !widget.profile.videoMuted && (widget.callSession.state == kWFAVEngineStateConnected || widget.callSession.state == kWFAVEngineStateOutgoing))?  Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                widget.callSession.switchCamera();
              },
              child: const Image(image:AssetImage('assets/images/rtckit/call_camera_switch.png', package: 'rtckit'), width: 24, height: 24,),
            )) : Container(),
      ],
    );
  }

  Widget _stateView(BuildContext context) {
    if(widget.profile.state == kWFAVEngineStateIncoming) {
      Future.delayed(const Duration(microseconds: 1), _startTimer);
      return Center(child: waitAnis[dotPos],);
    } else {
      Future.delayed(const Duration(microseconds: 1), _stopTimer);
      return Container();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          dotPos = (dotPos + 1) % 3;
        });
      });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }


  @override
  void dispose() {
    super.dispose();
    _stopTimer();
  }

  Widget _callView(BuildContext context) {
    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints.expand(),
          child: (userInfo == null || userInfo!.portrait == null) ? Image.asset(Rtckit.defaultUserPortrait) : Image.network(userInfo!.portrait!),
        ),
        ((widget.profile.state == kWFAVEngineStateConnected || widget.profile.state == kWFAVEngineStateOutgoing) && !widget.profile.videoMuted)?rtcView:Container()
      ],
    );
  }

  void updateProfile(ParticipantProfile profile) {
    widget.profile = profile;
    setState(() {

    });
  }

  Widget _createNativeVideoView(BuildContext context, String userId) {
    const String viewType = '<platform-view-type>';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    Widget? widget;
    if(defaultTargetPlatform == TargetPlatform.android) {
      widget = PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          rtcViewId = params.id;
          Future.delayed(const Duration(milliseconds: 100), _setupVideoView);
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
      return widget;
    } else if(defaultTargetPlatform == TargetPlatform.iOS) {
      widget = UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (viewId) {
          rtcViewId = viewId;
          Future.delayed(const Duration(milliseconds: 150), _setupVideoView);
        },
      );
      return widget;
    }

    return Container();
  }

  void _setupVideoView() {
    if(rtcViewId != null) {
      if(widget.profile.userId == Imclient.currentUserId) {
        widget.callSession.setLocalVideoView(rtcViewId!);
      } else {
        widget.callSession.setRemoteVideoView(widget.profile.userId, widget.profile.screenSharing, rtcViewId!);
      }
    }
  }
}