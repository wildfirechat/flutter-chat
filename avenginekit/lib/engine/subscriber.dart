import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_state.dart';

class Subscriber {
  String userId;
  CallState status = CallState.STATUS_IDLE;
  int joinTime = 0;
  int acceptTime = 0;
  bool audioMuted = false;
  bool videoMuted = false;

  RTCPeerConnection? peerConnection;
  bool isInitiator = false;
  bool hasReceivedSdp = false;
  List<RTCIceCandidate> queuedCandidates = [];

  MediaStream? stream;
  

  Subscriber(this.userId);
}
