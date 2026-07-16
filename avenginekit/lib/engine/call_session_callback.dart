import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_session.dart';
import 'call_state.dart';
import 'call_end_reason.dart';

abstract class CallSessionCallback {
  void onInitial(CallSession zc, String initiatorId);
  void didCallEndWithReason(CallEndReason reason);
  void didChangeState(CallState qd);
  void didParticipantJoined(String userId, {bool screenSharing = false});
  void didParticipantConnected(String userId, {bool screenSharing = false});
  void didParticipantLeft(String userId, CallEndReason reason, {bool screenSharing = false});
  void didChangeMode(bool audioOnly);
  void didCreateLocalVideo(MediaStream stream, {bool screenSharing = false});
  void didScreenShareEnded();
  void didReceiveRemoteVideo(String userId, MediaStream stream, {bool screenSharing = false});
  void didRemoveRemoteVideo(String userId);
  void didReportAudioVolume(String userId, int volume); 
  void didVideoMuted(String userId, bool muted);
  void didMuteStateChanged(List<String> participants);
  void didMediaLostPacket(String media, int lostPacket, {bool screenSharing = false});
  void didUserMediaLostPacket(String userId, String media, int lostPacket, bool uplink, {bool screenSharing = false});
  void didChangeInitiator(String initiator);
  void didChangeType(String userId, bool audience, {bool screenSharing = false});
  void onRequestChangeMode(bool audience);
  void onError(dynamic ya);
  void didGetStats(List<StatsReport> reports);
}
