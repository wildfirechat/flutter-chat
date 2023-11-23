import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/group_info.dart';
import 'package:rtckit/rtckit.dart';
import 'package:imclient/imclient.dart';
import 'package:rtckit/video_view.dart';
import 'call_state_view.dart';

class GroupVideoCallView extends StatefulWidget {
  String? groupId;
  List<String>? participants;
  List<ParticipantProfile>? profiles;
  CallSession? callSession;
  GroupVideoCallView({this.callSession, this.groupId, this.participants, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupVideoCallState();
}

class GroupVideoCallState extends State<GroupVideoCallView> implements CallSessionCallback {
  final Color backgroundColor = Colors.blue;

  Map<String, GlobalKey<VideoViewState>> rtcViewStateMap = {};
  Map<String, Widget> rtcViewMap = {};

  GlobalKey<CallStateViewState> stateGlobalKey = GlobalKey();

  GroupInfo? groupInfo;

  OverlayEntry? overlayEntry;

  @override
  void initState() {
    super.initState();
    if(widget.callSession == null) {
      if(widget.groupId == null && (widget.participants == null || widget.participants!.isEmpty)) {
        Navigator.pop(context);
        return;
      }

      Rtckit.startMultiCall(widget.groupId!, widget.participants!, false).then((value) {
        if (value == null) {
          Navigator.pop(context);
        } else {
          setState(() {
            loadProfiles();
            widget.callSession = value;
            widget.callSession?.setCallSessionCallback(this);
            widget.callSession?.startPreview();
          });
        }
      });
    } else {
      widget.groupId = widget.callSession?.conversation!.target;
      widget.callSession!.participantIds.then((value) {
        setState(() {
          loadProfiles();
        });
      });

      widget.callSession?.setCallSessionCallback(this);
    }

    Imclient.getGroupInfo(widget.groupId!).then((value) {
      setState(() {
        groupInfo = value;
      });
    });
  }

  void loadProfiles() {
    if(widget.callSession != null) {
      widget.callSession!.allProfiles.then((value) {
        setState(() {
          widget.profiles = value;
          createVideoView();
          updateVideoView();
        });
      });
    }
  }

  void createVideoView() {
    if(widget.profiles != null) {
      List<String> currentUsers = [];
      for (ParticipantProfile profile in widget.profiles!) {
        String userId = profile.userId;
        currentUsers.add(userId);
        if(!rtcViewMap.containsKey(userId)) {
          GlobalKey<VideoViewState> state = GlobalKey();
          Widget rtcView = VideoView(widget.callSession!, profile, key: state);
          rtcViewMap[userId] = rtcView;
          rtcViewStateMap[userId] = state;
        }
      }

      rtcViewMap.removeWhere((key, value) {
        if(!currentUsers.contains(key)) {
          rtcViewStateMap.remove(key);
          return true;
        }
        return false;
      });
    }
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
        //成员视频排列界面
        backgroundCallView(context),
        //控制视图，挂断静音等等
        hideControl ? Container() : controlView(context),
      ],
      ),
    );
  }

  bool hideControl = false;
  Widget backgroundCallView(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        if(widget.callSession!.state == kWFAVEngineStateConnected) {
          hideControl = !hideControl;
          setState(() {});
        }
      },
      child:Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: _getParticipantsView(),
      ),);
  }

  Widget _getParticipantsView() {
    int count = rtcViewMap.length;
    if(count < 2) {
      return const Center(child: Text("Loading..."),);
    }
    int columns = count > 5 ? 3 : 2;

    List<String> keysList = rtcViewMap.keys.toList();
    return GridView.builder(
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 0, mainAxisSpacing: 0, childAspectRatio: 1.0),
        itemBuilder: (context, index) {
          if(index < count) {
            return rtcViewMap[keysList[index]];
          } else {
            return Container();
          }
        });
  }

  Widget userPortraitAndName(BuildContext context) {
    if(groupInfo != null) {
      return Padding(padding: EdgeInsets.only(top: 80), child: Column(
        mainAxisSize:MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0), // 设置圆角半径
            child: SizedBox(width: 100,
              height: 100,
              child: groupInfo!.portrait == null
                  ? Image.asset(
                  Rtckit.defaultUserPortrait, width: 100.0, height: 100.0)
                  : Image.network(
                  groupInfo!.portrait!, width: 100.0, height: 100.0),
            ),
          ),
          const Padding(padding: EdgeInsets.all(8)),
          Center(child: Text(groupInfo!.name!, style: const TextStyle(color: Colors.white),),)
        ],
      ),);
    } else {
      return Container();
    }
  }

  List<Widget> _controlRowBottom1(BuildContext context) {
    if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
      return [_audioMuteControl(context), _speakerControl(context), _videoMuteControl(context)];
    } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
      //1 downgrade to voice call
      return [];
    } else {
      //1 downgrade to voice call
      return [_audioMuteControl(context), _speakerControl(context), _videoMuteControl(context)];
    }
  }

  List<Widget> _controlRowBottom2(BuildContext context) {
    if(widget.callSession!.state == kWFAVEngineStateOutgoing) {
      //3 button, mic, hangup, switch camera
      return [_hangupControl(context)];
    } else if(widget.callSession!.state == kWFAVEngineStateIncoming) {
      //2 button, hangup， accept
      return [_hangupControl(context), _acceptControl(context)];
    } else {
      //3 mic, hangup, switch camera
      return [_hangupControl(context)];
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

  Widget controlView(BuildContext context) {
    return Column(
      children: [
        (widget.callSession!.state == kWFAVEngineStateConnecting || widget.callSession!.state == kWFAVEngineStateConnected) ?
        Row(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 60, 0, 0), child: GestureDetector(onTap: () {
            showFloatingButton();
            Navigator.pop(context);
          }, child: const Image(image:AssetImage('assets/images/rtckit/call_minimize.png', package: 'rtckit'), width: 24, height: 24,),),),
          Expanded(child: Container()),
          widget.callSession == null ? Container() : Padding(padding: const EdgeInsets.fromLTRB(0, 60, 24, 0), child: GestureDetector(onTap: () {
            Imclient.getGroupMembers(widget.groupId!).then((groupMembers) {
              List<String> members = [];
              for(var gm in groupMembers) {
                members.add(gm.memberId);
              }

              List<String> inCallMembers = [];
              widget.profiles!.forEach((element) { inCallMembers.add(element.userId);});

              if(Rtckit.selectMembersDelegate != null) {
                Rtckit.selectMembersDelegate!(context, members, inCallMembers, null, Rtckit.maxAudioCallCount, (selected) {
                  Navigator.pop(context);
                  if(selected.isNotEmpty) {
                    widget.callSession!.inviteNewParticipants(selected);
                  }
                });
              }
            });
          }, child: const Image(image:AssetImage('assets/images/rtckit/call_plus.png', package: 'rtckit'), width: 24, height: 24,),),)
        ],):Container(),
        const Padding(padding: EdgeInsets.all(16)),
        Expanded(child: Container()),
        Center(child: CallStateView(widget.callSession!.state, widget.callSession!, key: stateGlobalKey,),),
        const Padding(padding: EdgeInsets.all(16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom1(context),
        ),
        const Padding(padding: EdgeInsets.all(16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _controlRowBottom2(context),
        ),
        const Padding(padding: EdgeInsets.all(16))
      ],
    );
  }

  bool swapPreview = false;

  void updateVideoView() {
    if(widget.callSession?.state == kWFAVEngineStateIdle) {
      return;
    }

    for(ParticipantProfile profile in widget.profiles!) {
      GlobalKey<VideoViewState>? state = rtcViewStateMap[profile.userId];
      if(state != null && state.currentState != null) {
        state.currentState!.updateProfile(profile);
      }
    }
  }

  Offset floatingStartOffset = const Offset(0, 0);
  Offset floatingEndOffset = const Offset(0, 0);
  Offset floatingPosition = const Offset(10, 120);
  void showFloatingButton() {
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: floatingPosition.dy + (floatingEndOffset.dy - floatingStartOffset.dy),
        right: floatingPosition.dx - (floatingEndOffset.dx - floatingStartOffset.dx),
        child: GestureDetector(
          onLongPressStart: (LongPressStartDetails details) {
            floatingStartOffset = details.globalPosition;
            floatingEndOffset = details.globalPosition;
          },
          onLongPressEnd: (LongPressEndDetails details){
            floatingPosition = Offset(floatingPosition.dx - (floatingEndOffset.dx - floatingStartOffset.dx), floatingPosition.dy + (floatingEndOffset.dy - floatingStartOffset.dy));
            floatingStartOffset = const Offset(0, 0);
            floatingEndOffset = const Offset(0, 0);
            overlayEntry?.markNeedsBuild();
          },
          onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
            floatingEndOffset = details.globalPosition;
            overlayEntry?.markNeedsBuild();
          },
          onTap: () {
            hideFloatingButton();
            GroupVideoCallView callView = GroupVideoCallView(callSession: widget.callSession!,);
            Navigator.push(context, MaterialPageRoute(builder: (context) => callView));},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10.0), // 圆角半径
            ),
            child: Column(
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(30, 20, 30, 0)),
              const Icon(Icons.call_rounded),
              const Padding(padding: EdgeInsets.only(top: 20)),
              Row(children: [Center(child: CallStateView(widget.callSession!.state, widget.callSession!),)],),
              const Padding(padding: EdgeInsets.only(top: 10)),
            ],),
          ),),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void hideFloatingButton() {
    if(overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  @override
  void didCallEndWithReason(CallSession session, int reason) {
    if(overlayEntry != null) {
      hideFloatingButton();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void didChangeInitiator(CallSession session, String? initiator) {
    // TODO: implement didChangeInitiator
    loadProfiles();
  }

  @override
  void didChangeMode(CallSession session, bool isAudioOnly) {
    loadProfiles();
  }

  @override
  void didChangeState(CallSession session, int state) {
    if(stateGlobalKey.currentState != null) {
      stateGlobalKey.currentState!.updateCallStateView(state);
    }
    loadProfiles();
  }

  @override
  void didCreateLocalVideoTrack(CallSession session) {
    loadProfiles();
  }

  @override
  void didError(CallSession session, String error) {
    // TODO: implement didError
  }

  @override
  void didGetStats(CallSession session) {
    // TODO: implement didGetStats
  }

  @override
  void didParticipantConnected(CallSession session, String userId, bool screenSharing) {
    loadProfiles();
  }

  @override
  void didParticipantJoined(CallSession session, String userId, bool screenSharing) {
    loadProfiles();
  }

  @override
  void didParticipantLeft(CallSession session, String userId, bool screenSharing, int reason) {
    loadProfiles();
  }

  @override
  void didReceiveRemoteVideoTrack(CallSession session, String userId, bool screenSharing) {
    loadProfiles();
  }

  @override
  void didVideoMuted(CallSession session, String userId, bool videoMuted) {
    loadProfiles();
  }

  @override
  void didChangeAudioRoute(CallSession session) {
    // TODO: implement didChangeAudioRoute
  }

  @override
  void didChangeType(CallSession session, String userId, bool audience) {
    loadProfiles();
  }

  @override
  void didMediaLost(CallSession session, String media, int lostPackage, bool screenSharing) {
    // TODO: implement didMediaLost
  }

  @override
  void didMuteStateChanged(CallSession session, List<String> userIds) {
    loadProfiles();
  }

  @override
  void didRemoteMediaLost(CallSession session, String userId, String media, bool uplink, int lostPackage, bool screenSharing) {
    // TODO: implement didRemoteMediaLost
  }

  @override
  void didReportAudioVolume(CallSession session, String userId, int volume) {
    // TODO: implement didReportAudioVolume
  }
}