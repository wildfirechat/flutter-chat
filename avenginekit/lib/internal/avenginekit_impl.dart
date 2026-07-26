import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/notification/call_add_participants_notificiation_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';

import '../engine/avenginekit.dart';
import '../engine/avengine_callback.dart';
import '../engine/call_session.dart';
import '../engine/call_state.dart';
import '../engine/call_end_reason.dart';
import '../engine/video_profile.dart';
import '../messages/signal_message_content.dart';
import '../messages/answer_message_content.dart';
import '../messages/bye_message_content.dart';
import '../messages/call_modify_message_content.dart';
import '../messages/mute_video_message_content.dart';
import 'call_session_impl.dart';

class a extends AVEngineKit {
  static const String g = 'avEngineKit';
  static final a ib = a._l();

  a._l();

  AVEngineCallback? w;
  
  b? _k;

  @override
  CallSession? get currentSession => _k;

  set currentSession(CallSession? zc) {
    if (zc == null) {
      _k = null;
    } else if (zc is b) {
      _k = zc;
    }
  }

  Map<String, List<Map<String, dynamic>>> rc = {};
  String vc = '';

  StreamSubscription? _msgSubscription;

  @override
  void init(AVEngineCallback ca) {
    // 防重复 init:重复调用会重复注册消息内容并重复监听信令消息,直接返回
    if (_msgSubscription != null) return;
    print('$g init');
    w = ca;

    Imclient.registerMessageContent(answerContentMeta);
    Imclient.registerMessageContent(byeContentMeta);
    Imclient.registerMessageContent(callModifyContentMeta);
    Imclient.registerMessageContent(muteVideoContentMeta);
    Imclient.registerMessageContent(signalContentMeta);

    // 保留订阅句柄,便于后续提供 dispose/reset 路径时取消
    _msgSubscription = Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((za) {
      onReceiveMessages(za.messages, za.hasMore);
    });
  }

  @override
  void onReceiveMessages(List<Message> messages, bool hasMore) async{
    if (hasMore) return;

    if (vc.isEmpty) {
      vc = Imclient.currentUserId;
    }

    for (var rb in messages) {
      var content = rb.content;
      if (kDebugMode) print('$g receive voip message ${content.meta.type} $rb');

      if ((rb.conversation.conversationType == ConversationType.Single ||
           rb.conversation.conversationType == ConversationType.Group) &&
          (rb.direction.index == 1 || 
           content.meta.type == VOIP_CONTENT_TYPE_ACCEPT ||
           content.meta.type == VOIP_CONTENT_TYPE_END)) {

        if (content.meta.type == VOIP_CONTENT_TYPE_SIGNAL) {
          if (_k == null || _k!.status == CallState.STATUS_IDLE) {
             continue;
          }
          var jd = content as SignalMessageContent;
          if (jd.callId != _k!.callId) {
             tc(rb.conversation, jd.callId, [], rb.messageUid!);
          } else {
             if (_k!.status == CallState.STATUS_CONNECTING ||
                 _k!.status == CallState.STATUS_CONNECTED ||
                 _k!.status == CallState.STATUS_OUTGOING) {
                 gc(rb.fromUser, jd.payload);
             }
          }

        } else if (content.meta.type == VOIP_CONTENT_TYPE_START) {
          if (kDebugMode) print('$g callstart $rb');
          var aa = content as CallStartMessageContent;
          var targetIds = List<String>.from(aa.targetIds!);

          if (!targetIds.contains(vc)) {
            continue;
          }

          targetIds.remove(vc);
          targetIds.add(rb.fromUser);

          if (_k != null && _k!.callId == aa.callId) {
             print('$g ignore duplicated call start message');
             continue;
          } else if (_k != null && _k!.status != CallState.STATUS_IDLE) {
             tc(rb.conversation, aa.callId, targetIds, rb.messageUid!);
          } else {
             _k = b.wb(
                 rb.conversation, rb.fromUser, aa.callId, aa.audioOnly, null 
             );
             
             

             _k!.pd = rb.messageUid!;
             _k!.hb(false, targetIds);
             _k!.ed(CallState.STATUS_INCOMING);
             _k!.joinTime = rb.serverTime;

             _k!.gd(rb.fromUser, rb.serverTime);
             for(var wd in aa.targetIds!) {
               _k!.gd(wd, rb.serverTime);
             }
             await _k!.fd(rb.fromUser, rb.serverTime);

             if (w != null) {
               w!.onReceiveCall(_k!);
             }
          }

        } else if (content.meta.type == VOIP_CONTENT_TYPE_ACCEPT ||
                   content.meta.type == VOIP_CONTENT_TYPE_ACCEPT_T) {
           var n = content as AnswerMessageContent;
           if (_k != null && _k!.status != CallState.STATUS_IDLE) {
              if (n.callId != _k!.callId) {
                 if (rb.direction.index == 1) { 
                    tc(rb.conversation, n.callId, [vc], rb.messageUid!);
                 }
                 continue;
              } else {
                 if (rb.direction.index == 0 && _k!.status == CallState.STATUS_INCOMING) { 
                    
                    _k!.sa(CallEndReason.REASON_AcceptByOtherClient);
                    continue;
                 }
              }

              if (_k!.status == CallState.STATUS_OUTGOING) {
                 _k!.ed(CallState.STATUS_CONNECTING);
              }
              if (!_k!.audioOnly && n.audioOnly) {
                 _k!.cd(true);
              }
              await _k!.fd(rb.fromUser, rb.serverTime);

              var sc = rc[rb.fromUser];
              if (sc != null) {
                 for(var uc in sc) {
                    nc(rb.fromUser, uc);
                 }
                 rc.remove(rb.fromUser);
              }
           }
        } else if (content.meta.type == VOIP_CONTENT_TYPE_END) {
            var x = content as ByeMessageContent;
            if (_k == null || _k!.status == CallState.STATUS_IDLE ||
                _k!.callId != x.callId) {
                 print('$g invalid bye message, ignore it');
            } else {
                int reason = x.reason;
                if (rb.direction.index == 1) { 
                   
                   
                   
                   

                   
                  
                   
                  _k!.va(rb.fromUser, CallEndReason.values[reason]);
                } else {
                  
                   _k!.sa(CallEndReason.values[reason]);
                }
            }
        } else if (content.meta.type == VOIP_CONTENT_TYPE_MODIFY) {
            var pb = content as CallModifyMessageContent;
            if (_k != null && _k!.status == CallState.STATUS_CONNECTED &&
                _k!.callId == pb.callId) {
                  if (pb.audioOnly) {
                     _k!.audioOnly = true;
                     _k!.pa(true);
                  } else {
                     print('$g cannot modify voice call to video call');
                  }
            }
        } else if (content.meta.type == VOIP_CONTENT_TYPE_ADD_PARTICIPANT) {
            var m = content as CallAddParticipantsNotificationContent;
            if (m.participants!.contains(vc)) {
                
                List<String> targets = [];
                targets.addAll(m.participants!);
                if (m.existParticipants != null) {
                   
                   for(var xa in m.existParticipants!) {
                      targets.add(xa['userId']);
                   }
                }
                targets.add(rb.fromUser);
                targets.removeWhere((xd) => xd == vc);

                if (_k != null && _k!.status != CallState.STATUS_IDLE) {
                   tc(rb.conversation, m.callId, targets, rb.messageUid!);
                   continue;
                }

                _k = b.wb(
                   rb.conversation, rb.fromUser, m.callId, m.audioOnly, null
                );
                _k!.pd = rb.messageUid!;
                _k!.hb(false, targets);
                _k!.joinTime = rb.serverTime;

                for(var wd in targets) {
                  _k!.gd(wd, rb.serverTime);
                }
                if (m.existParticipants != null) {
                  _k!.zd(m.existParticipants!, rb.serverTime);
                }

                if (w != null) {
                  w!.onReceiveCall(_k!);
                }
            } else {
               
               if (_k == null || _k!.status == CallState.STATUS_IDLE || _k!.callId != m.callId) {
                  
               } else {
                  if (m.participants != null) {
                    _k!.ma(m.participants!);
                    for(var wd in m.participants!) {
                       _k!.gd(wd, rb.serverTime);
                    }
                  }
               }
            }
        } else if (content.meta.type == VOIP_CONTENT_MUTE_VIDEO) {
            var muteVideo = content as MuteVideoMessageContent;
            if (_k != null && _k!.callId == muteVideo.callId && _k!.status != CallState.STATUS_IDLE) {
               _k!.ae(rb.fromUser, muteVideo.videoMuted);
            }
        }
      }
    }
  }

  @override
  void onConferenceEvent(String ga) {
    _k?.onConferenceEvent(ga);
  }

  void gc(String userId, String data) {
    try {
      Map<String, dynamic> jd = jsonDecode(data);
      if (_k?.db(userId) == null) {
        print('$g queue signal $userId $jd');
        if (!rc.containsKey(userId)) {
          rc[userId] = [];
        }
        var sc = rc[userId]!;
        if (jd['type'] == 'answer' || jd['type'] == 'offer') {
          print('$g queue signal answer/offer');
          sc.insert(0, jd);
        } else {
          sc.add(jd);
        }
      } else {
        nc(userId, jd);
      }
    } catch (qa) {
      print('$g onReceiveData error $qa');
    }
  }

  void nc(String userId, Map<String, dynamic> jd) {
    print('$g process remote signal: $userId ${jd['type']}');
    String type = jd['type'];
    if (type == 'offer') {
      RTCSessionDescription yb = RTCSessionDescription(jd['sdp'], type);
      _k?.ic(userId, yb);
    } else if (type == 'answer') {
      RTCSessionDescription r = RTCSessionDescription(jd['sdp'], type);
      _k?.hc(userId, r);
    } else if (type == 'candidate') {
      RTCIceCandidate candidate = RTCIceCandidate(
          jd['candidate'], jd['id'], jd['label']);
      _k?.dd(userId, candidate);
    }
  }

  void ac(String userId, RTCSessionDescription desc) {
    print('$g send engine answer/offer');
    Map<String, dynamic> xb = {
      'type': desc.type,
      'sdp': desc.sdp
    };
    yc(xb, [userId], true);
  }

  void ec(String userId, Map<String, dynamic> candidate) {
    print('$g send engine candidate $candidate');
    yc(candidate, [userId], true);
  }

  @override
  void startCall(Conversation conversation, List<String> participants, bool audioOnly, {String callExtra = ''}) {
    if (_k != null) return;
    if (w == null) {
      print('$g avengineCallback is null');
      return;
    }
    if (vc.isEmpty) vc = Imclient.currentUserId;

    
    String callId = '$vc|${DateTime.now().millisecondsSinceEpoch}';

    _k = b.wb(conversation, vc, callId, audioOnly, null);
    _k!.hb(true, participants);
    _k!.ed(CallState.STATUS_OUTGOING);

    if (w != null) {
      w!.onStartCall(_k!);
    }

    
    
    
    
    
    var nd = CallStartMessageContent();
    nd.callId = callId;
    nd.targetIds = participants;
    nd.audioOnly = audioOnly;
    nd.sdkType = 1;

    xc(nd, _k!.getParticipantIds(), true, (ya, messageUid, td) {
       if (_k == null) return;
       if (ya != 0) {
         _k!.sa(CallEndReason.REASON_SignalError);
       } else {
         _k!.pd = messageUid!;
         _k!.joinTime = td!;
         _k!.ad(td);
         for(var kc in nd.targetIds!) {
           _k!.gd(kc, td);
         }
       }
    });
  }

  void inviteNewParticipants(List<String> vb, String sd, bool v) {
    var zc = _k;
    if (zc == null) return;

    var add = CallAddParticipantsNotificationContent();
    add.callId = zc.callId;
    add.initiator = vc; 
    add.audioOnly = zc.audioOnly;
    add.participants = vb;
    add.existParticipants = zc.bb();
    add.autoAnswer = v;
    add.clientId = sd;

    

    var toUsers = [...zc.getParticipantIds()];
    toUsers.addAll(vb);

    xc(add, toUsers, true, (ya, messageUid, td) {
       if (ya != 0) return;
       zc.ma(vb);
       for (var xd in vb) {
         zc.gd(xd, td!);
       }
    });
  }

  // 调用方已通过 getMessageByUid 拿到 message,直接复用其 messageId,避免重复查询
  void yd(Message nb, CallStartMessageContent content) {
    Imclient.updateMessage(nb.messageId, content);
  }

  void xc(MessageContent sb, List<String> targetIds, bool keyMsg, Function(int, int?, int?)? ca) {
     if (_k == null || _k!.conversation == null) return;

     Imclient.sendMessage(_k!.conversation!, sb, toUsers: targetIds, successCallback: (messageUid, td) {
       if (ca != null) ca(0, messageUid, td);
     }, errorCallback: (fa) {
       if (ca != null) ca(fa, null, null);
     });
  }

  void yc(Map<String, dynamic> nb, List<String> targets, bool kb) {
    var kd = SignalMessageContent(
      callId: _k!.callId,
      payload: jsonEncode(nb)
    );
    xc(kd, targets, kb, null);
  }

  void wc(String callId, List<dynamic> existParticipants, bool videoMuted, List<String> targets) {
     var content = MuteVideoMessageContent();
     content.callId = callId;
     content.videoMuted = videoMuted;
     
     xc(content, targets, true, null);
  }

  void tc(Conversation conversation, String callId, List<String> targetIds, int od) {
    var y = ByeMessageContent(callId: callId, reason: CallEndReason.REASON_Busy.index, inviteMsgUid: od);
    Imclient.sendMessage(conversation, y, toUsers: targetIds, successCallback: (xd, ts) {}, errorCallback: (qa) {});
  }

  void o() {
    if (_k == null) return;

    var q = AnswerMessageContent(
      callId: _k!.callId,
      audioOnly: _k!.audioOnly,
      inviteMsgUid: _k!.pd
    );

    xc(q, _k!.getParticipantIds(), true, (ya, messageUid, td) {
      if (ya == 0) {
        _k!.ad(td!);
      } else {
        _k!.sa(CallEndReason.REASON_SignalError);
      }
    });
  }

  void oa() {
     if (_k == null) return;
     var qb = CallModifyMessageContent();
     qb.audioOnly = true;
     qb.callId = _k!.callId;
     xc(qb, _k!.getParticipantIds(), true, null);
  }

  @override
  bool isSupportConference() {
    return false;
  }

  @override
  CallSession? joinConference(String callId, bool audioOnly, String pin, String host, String title, String desc, bool audience, bool advance, bool muteAudio, bool muteVideo, String extra, String callExtra, {int defaultVideoType = VideoProfile.VP360P}) {
    
    return null;
  }

  @override
  Future<CallSession?> startConference(String callId, bool audioOnly, String pin, String host, String title, String desc, bool audience, bool advance, bool record, String extra, String callExtra, {bool muteAudio = false, bool muteVideo = false, int defaultVideoType = VideoProfile.VP360P}) async {
    
    return null;
  }
}

final a avEngineKit = a.ib;
