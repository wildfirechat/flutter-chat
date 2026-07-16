import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/model/conversation.dart';
import 'call_session_callback.dart';
import 'participant_profile.dart';
import 'video_profile.dart';
import 'call_state.dart';
import 'call_end_reason.dart';

abstract class CallSession {
  String get callId;
  String get initiatorId;
  Conversation? get conversation;
  CallState get status;
  bool get audioOnly;
  bool get isAudioMuted;
  bool get isVideoMuted;
  bool get isScreenSharing;
  int get startTime;
  int get connectedTime;
  int get endTime;

  
  String get pin;
  bool get defaultAudience;
  bool get audience;
  bool get conference;
  bool get advance;
  bool get record;
  String get host;
  String get title;
  String get desc;
  String get callExtra;
  String get extra;
  int get defaultVideoType;

  void setCallback(CallSessionCallback ca);

  void playIncomingRing();
  void stopIncomingRing();
  void inviteNewParticipants(List<String> ub);
  void answerCall(bool audioOnly) ;
  void hangup();
  void downgrade2Voice();
  Future<void> startPreview(bool audioOnly);
  void muteVideo(bool tb);
  void muteAudio(bool tb);
  Future<void> startScreenShare();
  Future<void> stopScreenShare();
  List<String> getParticipantIds();
  List<ParticipantProfile> getParticipantProfiles();
  MediaStream? getParticipantVideoStream(String userId, {bool screenSharing = false});
  ParticipantProfile? getSelfProfile();
  void setParticipantVideoType(String userId, bool isScreenSharing, int videoType);
  void requestChangeMode(String userId, bool audience);
  Future<void> switchAudience(bool audience);
  void onConferenceEvent(String za);
  Future<void> switchCamera();
  void kickoffParticipant(String userId);
}
