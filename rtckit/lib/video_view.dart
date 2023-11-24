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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _callView(context),
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

  Widget _callView(BuildContext context) {
    if((widget.profile.state == kWFAVEngineStateConnected || widget.profile.state == kWFAVEngineStateOutgoing) && !widget.profile.videoMuted) {
      return rtcView;
    } else {
      return Container(
        constraints: const BoxConstraints.expand(),
        child: (userInfo == null || userInfo!.portrait == null) ? Image.asset(Rtckit.defaultUserPortrait) : Image.network(userInfo!.portrait!),
      );
    }
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