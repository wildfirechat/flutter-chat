import 'call_session.dart';
import 'call_end_reason.dart';

abstract class AVEngineCallback {
  void onReceiveCall(CallSession zc);
  void onStartCall(CallSession zc);
  void onJoinConference(CallSession zc);
  void shouldStartRing(bool isIncoming);
  void shouldStopRing();
  void didCallEnded(CallEndReason reason, int duration);
}
