import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/message/call_start_message_content.dart';
import '../engine/call_session.dart';
import '../engine/call_state.dart';
import '../engine/call_end_reason.dart';
import '../engine/call_session_callback.dart';
import '../engine/participant_profile.dart';
import '../engine/subscriber.dart';
import '../engine/video_profile.dart';
import '../messages/bye_message_content.dart';
import '../messages/answer_message_content.dart'; 
import 'avenginekit_impl.dart';
import 'config.dart';

class b extends CallSession {
  static const String g = 'avEngineKit';

  @override
  String callId = '';
  @override
  String initiatorId = '';
  @override
  Conversation? conversation;
  @override
  CallState status = CallState.STATUS_IDLE;
  @override
  bool audioOnly = false;
  @override
  bool isAudioMuted = false;
  @override
  bool isVideoMuted = false;
  @override
  bool isScreenSharing = false;
  @override
  int startTime = 0;
  @override
  int connectedTime = 0;
  @override
  int endTime = 0;

  
  @override
  String get pin => '';
  @override
  bool get defaultAudience => false;
  @override
  bool get audience => false;
  @override
  bool get conference => false;
  @override
  bool get advance => false;
  @override
  bool get record => false;
  @override
  String get host => '';
  @override
  String get title => '';
  @override
  String get desc => '';
  @override
  String get callExtra => '';
  @override
  String get extra => '';
  @override
  int get defaultVideoType => VideoProfile.VP360P;

  CallSessionCallback? _i;

  int joinTime = 0;
  int acceptTime = 0;
  CallEndReason ua = CallEndReason.REASON_Unknown;
  String vc = '';
  List<String> participants = [];
  bool ob = false;
  MediaStream? da;
  bool cb = false;
  String be = 'user';
  Timer? ba;
  // serverDeltaTime 为准静态值,缓存一次复用,避免每秒一次平台调用
  int? _cachedServerDeltaTime;
  Map<String, Subscriber> mc = {};
  List<UserInfo> groupMemberUserInfos = [];
  bool ld = false;

  
  
  
  

  int pd = 0;

  static b wb(Conversation conversation, String initiatorId, String callId, bool audioOnly, CallSessionCallback? ca) {
    var zc = b();
    zc.conversation = conversation;
    zc.initiatorId = initiatorId;
    zc.callId = callId;
    zc.audioOnly = audioOnly;
    zc._i = ca;

    return zc;
  }

  Subscriber? ab(String userId) {
    return mc[userId];
  }

  @override
  List<String> getParticipantIds() {
    return participants;
  }

  @override
  void setCallback(CallSessionCallback ca) {
    _i = ca;
  }

  void ad(int td) {
    acceptTime = td;
    vd();
  }

  Future<void> fd(String userId, int td) async {
    if (userId == vc) {
      return;
    }
    print('$g setUserAcceptTime $userId $td');
    var ea = ab(userId);
    if (ea != null) {
      ea.acceptTime = td;
      await vd();
    }
  }

  void gd(String userId, int td) {
    var ea = ab(userId);
    if (ea != null) {
      ea.joinTime = td;
    }
  }

  Future<void> vd() async {
    if (acceptTime > 0) {
      for (var wa in mc.entries) {
        var userId = wa.key;
        var ea = wa.value;
        if (ea.acceptTime > 0 &&
           (ea.status == CallState.STATUS_INCOMING || ea.status == CallState.STATUS_OUTGOING)) {
            if (acceptTime > ea.acceptTime) {
              await md(userId, true);
            } else {
              await md(userId, false);
            }
        }
      }
    }
  }

  RTCPeerConnection? db(String userId) {
    var ea = mc[userId];
    return ea?.peerConnection;
  }

  @override
  List<ParticipantProfile> getParticipantProfiles() {
    List<ParticipantProfile> qc = [];
    for (var ea in mc.values) {
      var kc = ParticipantProfile(ea.userId);
      kc.status = ea.status;
      kc.joinTime = ea.joinTime;
      kc.acceptTime = ea.acceptTime;
      kc.audioMuted = ea.audioMuted;
      kc.videoMuted = ea.videoMuted;
      qc.add(kc);
    }
    return qc;
  }

  @override
  MediaStream? getParticipantVideoStream(String userId, {bool screenSharing = false}) {
    if (userId == Imclient.currentUserId) {
      var stream = da;
      return stream;
      
      
      
      
      
      
    }
    var ea = mc[userId];
    return ea?.stream;
  }

  @override
  ParticipantProfile? getSelfProfile() {
    var oc = ParticipantProfile(vc);
    oc.status = status;
    oc.joinTime = joinTime;
    oc.acceptTime = acceptTime;
    oc.audioMuted = isAudioMuted;
    oc.videoMuted = isVideoMuted;
    return oc;
  }

  @override
  void answerCall(bool audioOnly) {
    if (status != CallState.STATUS_INCOMING) {
      return;
    }
    ed(CallState.STATUS_CONNECTING);
    if (this.audioOnly && !audioOnly) {
      audioOnly = true;
    }
    this.audioOnly = audioOnly;
    a.ib.o();
  }

  void ed(CallState status) {
    if (this.status == status) {
      if (status == CallState.STATUS_CONNECTED && _i != null) {
        _i!.didChangeState(status);
      }
      return;
    }
    if (this.status == CallState.STATUS_CONNECTED && status == CallState.STATUS_CONNECTING) {
      return;
    }

    this.status = status;
    print('$g set status $status $pd');

    if (status == CallState.STATUS_CONNECTED) {
      connectedTime = DateTime.now().millisecondsSinceEpoch;
      
      
      

      Imclient.getMessageByUid(pd).then((rb) {
         if (rb != null && rb.content is CallStartMessageContent) {
           var content = rb.content as CallStartMessageContent;
           content.connectTime = DateTime.now().millisecondsSinceEpoch;
           
           
           
           a.ib.yd(rb, content);
         }
      });

      if (cb && status == CallState.STATUS_CONNECTED) {
        muteVideo(true);
        if (_i != null) {
           _i!.didVideoMuted(vc, true);
        }
      }
    } else if (status == CallState.STATUS_IDLE) {
      if (pd > 0) {
        Imclient.getMessageByUid(pd).then((rb) {
          if (rb != null && rb.content is CallStartMessageContent) {
            var content = rb.content as CallStartMessageContent;
            content.status = ua.index;
            content.endTime = DateTime.now().millisecondsSinceEpoch;
            a.ib.yd(rb, content);
          }
        });
      }
    }

    if (_i != null) {
      _i!.didChangeState(status);
    }
  }

  void cd(bool audioOnly) {
    this.audioOnly = audioOnly;
    if (_i != null) {
      _i!.didChangeMode(audioOnly);
    }
  }

  void hb(bool ob, List<String> participants) {
    this.ob = ob;
    vc = Imclient.currentUserId;
    this.participants = participants;
    ld = participants.length == 1;

    if (_i != null) {
      _i!.onInitial(this, initiatorId);
    }

    gb(participants);

    if (ob) {
      ed(CallState.STATUS_OUTGOING);
      startPreview(audioOnly);
    } else {
      ed(CallState.STATUS_INCOMING);
      playIncomingRing();
    }
    _h();
  }

  void _h() async {
    
    ba ??= Timer.periodic(Duration(seconds: 1), (timer) async {
       int now = DateTime.now().millisecondsSinceEpoch;
       int joinTime = this.joinTime;
       if (joinTime == 0) return;

       int ka = _cachedServerDeltaTime ??= await Imclient.serverDeltaTime;

       if (status == CallState.STATUS_INCOMING) {
         if (now - joinTime + ka > 60 * 1000) {
           sa(CallEndReason.REASON_Timeout);
         }
       } else if (status != CallState.STATUS_CONNECTED) {
         if (now - joinTime + ka > 60 * 1000) {
           sa(CallEndReason.RemoteTimeout);
         }
       }

       mc.forEach((userId, ea) {
          int lb = (ea.acceptTime > 0) ? ea.acceptTime : ea.joinTime;
          if (ea.status != CallState.STATUS_CONNECTED &&
              lb > 0 &&
              now - lb + ka > 60 * 1000) {
                va(userId, CallEndReason.RemoteTimeout);
          }
       });
    });
  }

  void gb(List<String> participants) {
    print('$g initParticipantClientMap $participants');
    for (var xd in participants) {
      var ea = Subscriber(xd);
      if (xd == vc) {
        ea.status = CallState.STATUS_OUTGOING;
      } else {
        ea.status = CallState.STATUS_INCOMING;
      }
      mc[xd] = ea;
    }
  }

  
  void jb(List<String> ub, String sd, bool v) {
    if (ub.isEmpty) return;

    
    ub = ub.where((xd) => xd != vc && !participants.contains(xd)).toList();
    if (ub.isEmpty) return;

    ld = false;
    a.ib.inviteNewParticipants(ub, sd, v);
  }

  @override
  void inviteNewParticipants(List<String> ub) {
    jb(ub, '', false);
  }

  
  
  
  
  
  
  
  
  

  
  List<dynamic> bb() {
    List<dynamic> rd = [];
    rd.add({
      'userId': vc,
      'acceptTime': acceptTime,
      'joinTime': joinTime,
      'videoMuted': isVideoMuted
    });

    for (var wd in participants) {
      var ea = ab(wd);
      if (ea != null) {
        rd.add({
          'userId': ea.userId,
          'acceptTime': ea.acceptTime,
          'joinTime': ea.joinTime,
          'videoMuted': ea.videoMuted
        });
      }
    }
    return rd;
  }

  void ma(List<String> vb) {
    print('$g didAddNewParticipants $vb');
    for (var kc in vb) {
      var ea = Subscriber(kc);
      ea.status = CallState.STATUS_INCOMING;
      mc[kc] = ea;
      if (_i != null) {
        _i!.didParticipantJoined(kc, screenSharing: false);
      }
    }
  }

  void zd(List<dynamic> existParticipants, int joinTime) {
     for (var kc in existParticipants) {
       
       
       String userId = kc['userId'];
       var ea = ab(userId);
       if (ea != null) {
         ea.status = CallState.STATUS_INCOMING;
         ea.joinTime = joinTime;
         ea.videoMuted = kc['videoMuted'];
         ea.acceptTime = kc['acceptTime'];
       }
     }
  }

  void ae(String userId, bool videoMuted) {
    var ea = ab(userId);
    if (ea != null && ea.videoMuted != videoMuted) {
      ea.videoMuted = videoMuted;
      if (_i != null) {
        _i!.didVideoMuted(userId, videoMuted);
      }
    }
  }

  Map<String, dynamic> ja(bool audioOnly) {
    if (audioOnly) {
      return {
        'audio': true,
        'video': false,
      };
    } else {
      
      
      
      return {
        'audio': true,
        'video': {
          'width': 640,
          'height': 480,
          'frameRate': 15,
          'facingMode': be
        }
      };
    }
  }

  Future<MediaStream> ia(bool audioOnly) async {
    print('$g createLocalCameraVideoStream $audioOnly');
    final stream = await navigator.mediaDevices.getUserMedia(ja(audioOnly));
    print('$g Received local stream ${stream.id} ${stream.getVideoTracks().length} $audioOnly');

    if (_i != null && !isVideoMuted) {
       
       Future.delayed(Duration.zero, () {
         if (stream.getVideoTracks().isNotEmpty) {
           _i!.didCreateLocalVideo(stream);
         }
       });
    }

    if (!audioOnly) {
      if (stream.getVideoTracks().isNotEmpty) {
        print('$g Using video device: ${stream.getVideoTracks()[0].id}');
      }
    } else {
      if (stream.getVideoTracks().isNotEmpty) {
        print('$g audioOnly, stop video track');
        stream.getVideoTracks().forEach((ud) => ud.stop());
      }
    }

    da = stream;
    return stream;
  }

  @override
  Future<void> startPreview(bool audioOnly) async {
    print('$g start preview');
    if (conference && audience) {
      return;
    }
    try {
      await ia(audioOnly);
    } catch (qa) {
      print('$g start preview error $qa');
      sa(CallEndReason.REASON_MediaError);
    }
  }

  Future<void> md(String userId, bool isInitiator) async {
    print('$g start media $isInitiator');
    ed(CallState.STATUS_CONNECTING);
    startTime = DateTime.now().millisecondsSinceEpoch;
    var ea = ab(userId);
    if (ea != null) {
      ea.status = CallState.STATUS_CONNECTING;
      if (isInitiator) {
        if (da == null) {
          await startPreview(audioOnly);
        }
        await _j(userId, isInitiator);
      } else {
        await _j(userId, isInitiator);
      }
    }
  }

  Future<void> _j(String userId, bool isInitiator) async {
    print('$g createPeerConnection $userId $isInitiator');
    var ea = ab(userId);
    if (ea == null) return;

    Map<String, dynamic> ha = {
      'iceServers': d.f.map((qa) => {
        'urls': qa[0],
        'username': qa[1],
        'credential': qa[2]
      }).toList(),
      'sdpSemantics': 'unified-plan',
    };

    RTCPeerConnection lc = await createPeerConnection(ha);

    if (da != null) {
      if (da!.getAudioTracks().isNotEmpty) {
        await lc.addTrack(da!.getAudioTracks()[0], da!);
      }
      if (!audioOnly && da!.getVideoTracks().isNotEmpty) {
        await lc.addTrack(da!.getVideoTracks()[0], da!);
      }
    }

    ea.peerConnection = lc;
    ea.isInitiator = isInitiator;

    print('$g Created local peer connection object pc $userId');

    lc.onIceCandidate = (candidate) {
      ec(userId, lc, candidate);
    };

    lc.onTrack = (za) {
      eb(userId, za);
    };

    lc.onIceConnectionState = (qd) {
      fc(userId, lc, qd);
    };

    
    lc.onConnectionState = (qd) {
      print('$g onConnectionState $qd');
       zb(userId, lc, qd);
    };

    if (isInitiator) {
      try {
        print('$g pc createOffer start');
        RTCSessionDescription la = await lc.createOffer({});
        cc(userId, la);
      } catch (qa) {
        dc(userId, qa);
      }
    }
  }

  @override
  void call() {
    print('$g voip on call button click');
    stopIncomingRing();
    print('$g on call button call');
    answerCall(audioOnly);
  }

  void dc(String userId, dynamic ya) {
    print('$g Failed to create session description $ya');
    va(userId, CallEndReason.REASON_MediaError);
  }

  Future<void> ic(String userId, RTCSessionDescription desc) async {
    var ea = mc[userId];
    if (ea == null || ea.isInitiator) return;

    var lc = db(userId);
    print('$g onReceiveRemoteCreateOffer $userId pc == null${lc == null}');
    if (lc == null) return;

    try {
      await lc.setRemoteDescription(desc);
      if (kDebugMode) print('$g setRemoteDescription ${desc.type} ${desc.sdp}');
      ea.hasReceivedSdp = true;

      if (ea.queuedCandidates.isNotEmpty) {
         print('$g process pending ice candidates');
         for (var z in ea.queuedCandidates) {
           await dd(userId, z);
         }
         ea.queuedCandidates.clear();
      }

      print('$g pc createAnswer start');
      RTCSessionDescription n = await lc.createAnswer({});
      bc(userId, n);

    } catch (e) {
      
    }
  }

  Future<void> cc(String userId, RTCSessionDescription desc) async {
    print('$g pc setLocalDescription start');
    var ea = mc[userId];
    if (ea == null || !ea.isInitiator) return;

    var lc = db(userId);
    if (lc == null) return;

    try {
      await lc.setLocalDescription(desc);
    } catch (e) {
      
    }
    a.ib.ac(userId, desc);
  }

  void eb(String userId, RTCTrackEvent za) {
    if (audioOnly) return;

    if (za.streams.isEmpty) return;

    var de = za.streams[0].getVideoTracks();
    if (_i != null && de.isNotEmpty) {
      _i!.didReceiveRemoteVideo(userId, za.streams[0]);
    }

    var ea = ab(userId);
    if (ea != null) {
      
      ea.stream = za.streams[0];
    }
    print('$g pc received remote stream');
  }

  Future<void> hc(String userId, RTCSessionDescription desc) async {
    print('$g onReceiveRemoteAnswerOffer $userId');
    try {
      var ea = mc[userId];
      if (ea == null) return;
      var lc = ea.peerConnection;
      if (lc != null) {
        await lc.setRemoteDescription(desc);
        ea.hasReceivedSdp = true;
        if (ea.queuedCandidates.isNotEmpty) {
          print('$g process pending ice candidates');
          for (var z in ea.queuedCandidates) {
             await dd(userId, z);
          }
          ea.queuedCandidates.clear();
        }
      }
    } catch (e) {
      
    }
  }

  Future<void> dd(String userId, RTCIceCandidate candidate) async {
    if (kDebugMode) print('$g handle the candidate $candidate');
    jc(userId, candidate);
  }

  Future<void> bc(String userId, RTCSessionDescription desc) async {
    print('$g pc setLocalDescription start');
    try {
      var lc = db(userId);
      if (lc != null) {
        await lc.setLocalDescription(desc);
      }
    } catch (e) {
      
    }
    a.ib.ac(userId, desc);
  }

  void jc(String userId, RTCIceCandidate candidate) async {
    var ea = mc[userId];
    if (ea == null) return;

    if (kDebugMode) print('$g on receive remote ice candidate ${ea.hasReceivedSdp}');
    if (!ea.hasReceivedSdp) {
       if (kDebugMode) print('$g pc rdp is null');
       ea.queuedCandidates.add(candidate);
    } else {
       if (kDebugMode) print('$g pc rdp is set');
       var lc = ea.peerConnection;
       if (lc != null) {
         await lc.addCandidate(candidate);
       }
    }
  }

  void ec(String userId, RTCPeerConnection lc, RTCIceCandidate candidate) {
    try {
      Map<String, dynamic> xb = {
        'type': 'candidate',
        'label': candidate.sdpMLineIndex,
        'id': candidate.sdpMid,
        'candidate': candidate.candidate
      };
      a.ib.ec(userId, xb);
    } catch (qa) {
      print('$g onIceCandidate error $qa');
      va(userId, CallEndReason.REASON_MediaError);
    }
    if (kDebugMode) print('$g ICE candidate: ${candidate.candidate}');
  }

  void zb(String userId, RTCPeerConnection lc, RTCPeerConnectionState qd){
    print('$g pc state: $qd $userId');
    var ea = ab(userId);
    if (ea == null) return;

    if (qd == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      if(ea.status != CallState.STATUS_CONNECTED){
        ea.status = CallState.STATUS_CONNECTED;
        if (userId != vc) {
          if (_i != null) {
            _i!.didParticipantConnected(userId);
          }
        }
        ed(CallState.STATUS_CONNECTED);
      }
    
    
    }
  }

  void fc(String userId, RTCPeerConnection lc, RTCIceConnectionState qd) {
    print('$g ICE state: $qd $userId');
    var ea = ab(userId);
    if (ea == null) return;

    if (qd == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      
    } else if (qd == RTCIceConnectionState.RTCIceConnectionStateConnected) {
      if(ea.status != CallState.STATUS_CONNECTED) {
        ea.status = CallState.STATUS_CONNECTED;
        if (userId != vc) {
          if (_i != null) {
            _i!.didParticipantConnected(userId);
          }
        }
        ed(CallState.STATUS_CONNECTED);
      }
    } else if (qd == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      va(userId, CallEndReason.REASON_MediaError);
    }
  }

  @override
  void hangup() {
    print('$g Ending call');
    sa(CallEndReason.REASON_Hangup);
  }

  @override
  void downgrade2Voice() {
    pa(false);
  }

  void pa(bool fb) {
    if (status != CallState.STATUS_CONNECTED) {
      return;
    }
    var mb = da?.getVideoTracks();
    if (mb != null) {
      for (var ud in mb) {
        ud.stop();
      }
    }

    if (fb) {
      na();
    }
  }

  void na() {
    print('$g down to voice');
    stopIncomingRing();
    if (status == CallState.STATUS_INCOMING) {
      cd(true);
      answerCall(true);
      return;
    }
    if (status != CallState.STATUS_CONNECTED) {
      return;
    }
    if (audioOnly) return;

    cd(true);
    a.ib.oa();
  }

  @override
  void muteVideo(bool tb) {
    hd(!tb);
  }

  void hd(bool ra) {
    if (audioOnly || da == null) return;

    isVideoMuted = !ra;
    var mb = da!.getVideoTracks();
    for (var ud in mb) {
      ud.enabled = ra;
    }

    
    
    
    a.ib.wc(callId, bb(), isVideoMuted, getParticipantIds());
  }

  @override
  void muteAudio(bool tb) {
    bd(!tb);
    isAudioMuted = tb;
  }

  void bd(bool ra) {
    var t = da?.getAudioTracks();
    if (t != null) {
       for (var ud in t) {
         ud.enabled = ra;
       }
    }
  }

  void ta() {
    print('$g Ending media');
    ed(CallState.STATUS_IDLE);
    stopIncomingRing();

    if (da != null) {
      da!.getTracks().forEach((ud) {
        ud.stop();
      });
      da?.dispose();
      da = null;
    }

    mc.forEach((key, ea) {
       if (ea.stream != null) {
         ea.stream!.getTracks().forEach((ud) {
           ud.stop();
         });
         ea.stream!.dispose();
         ea.stream = null;
       }
       if (ea.peerConnection != null) {
         ea.peerConnection!.close();
       }
    });
    mc.clear();
  }

  void va(String userId, CallEndReason reason) {
    print('$g endUserCall $userId $reason');
    if (userId == vc) {
      sa(reason);
      return;
    }

    var ea = ab(userId);
    mc.remove(userId);
    participants.remove(userId);

    if (ea != null) {
      if (ea.stream != null) {
         ea.stream!.getTracks().forEach((ud) {
           ud.stop();
         });
         ea.stream!.dispose();
         ea.stream = null;
      }
      if (ea.peerConnection != null) {
         ea.peerConnection!.close();
      }
      if (_i != null && mc.isNotEmpty) {
        _i!.didParticipantLeft(userId, reason);
      }
    }

    if (mc.isEmpty) {
       if (conversation?.conversationType == ConversationType.Single || ld) {
         sa(reason);
       } else {
         sa(CallEndReason.REASON_AllLeft);
       }
    }
  }

  void sa(CallEndReason reason) {
    print('$g endCall $reason');
    ua = reason;
    if (status == CallState.STATUS_IDLE) {
      return;
    }
    ed(CallState.STATUS_IDLE);

    if (reason != CallEndReason.REASON_AcceptByOtherClient && reason != CallEndReason.REASON_AllLeft) {
       var y = ByeMessageContent(callId: callId);
       
       y.inviteMsgUid = pd;
       y.reason = reason.index;
       a.ib.xc(y, getParticipantIds(), false, null);
    }

    endTime = DateTime.now().millisecondsSinceEpoch;

    a.ib.currentSession = null;
    ba?.cancel();
    ta();

    if (_i != null) {
      _i!.didCallEndWithReason(reason);
    }
    if (a.ib.w != null) {
      a.ib.w!.didCallEnded(reason, (endTime - startTime) ~/ 1000); 
    }
  }

  @override
  Future<void> switchCamera() async {
    if (audioOnly) return;

    if (be == 'user') {
      be = 'environment';
    } else {
      be = 'user';
    }

    print('$g switch camera $be');

    try {
      if (da != null) {
        
        
        
        

        
        

        var de = da!.getVideoTracks();
        if (de.isNotEmpty) {
           
           
           
           
           
           

           
           
           
           
           
           

           await Helper.switchCamera(de[0]);
           return;
        }
      }
    } catch (qa) {
      print('switch camera error $qa');
    }
  }

  @override
  void playIncomingRing() {
    
    
  }

  @override
  void stopIncomingRing() {
    
  }

  
  @override
  Future<void> startScreenShare() async {}

  @override
  Future<void> stopScreenShare() async {}

  @override
  void requestChangeMode(String userId, bool audience) {}

  @override
  Future<void> switchAudience(bool audience) async {}

  @override
  void onConferenceEvent(String za) {}

  @override
  void kickoffParticipant(String userId) {}

  @override
  void setParticipantVideoType(String userId, bool isScreenSharing, int videoType) {}
}
