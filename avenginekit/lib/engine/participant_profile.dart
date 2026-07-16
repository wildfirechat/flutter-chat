import 'call_state.dart';

class ParticipantProfile {
  String userId = '';
  String callExtra = '';
  CallState status = CallState.STATUS_IDLE;
  int joinTime = 0;
  int acceptTime = 0;
  bool audioMuted = false;
  bool videoMuted = false;
  bool audience = false;
  bool screenSharing = false;

  ParticipantProfile(this.userId, {
    this.callExtra = '',
    this.status = CallState.STATUS_IDLE,
    this.joinTime = 0,
    this.acceptTime = 0,
    this.audioMuted = false,
    this.videoMuted = false,
    this.audience = false,
    this.screenSharing = false,
  });
}
