import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/message.dart';
import '../internal/avenginekit_impl.dart';
import 'call_session.dart';
import 'avengine_callback.dart';
import 'video_profile.dart';

abstract class AVEngineKit {
  void init(AVEngineCallback ca);
  CallSession? get currentSession;

  
  void onReceiveMessages(List<Message> messages, bool hasMore);

  
  void onConferenceEvent(String za);

  void startCall(Conversation conversation, List<String> participants, bool audioOnly, {String callExtra = ''});

  Future<CallSession?> startConference(
      String callId,
      bool audioOnly,
      String pin,
      String host,
      String title,
      String desc,
      bool audience,
      bool advance,
      bool record,
      String extra,
      String callExtra,
      {bool muteAudio = false,
      bool muteVideo = false,
      int defaultVideoType = VideoProfile.VP360P});

  CallSession? joinConference(
      String callId,
      bool audioOnly,
      String pin,
      String host,
      String title,
      String desc,
      bool audience,
      bool advance,
      bool muteAudio,
      bool muteVideo,
      String extra,
      String callExtra,
      {int defaultVideoType = VideoProfile.VP360P});

  bool isSupportConference();
}

final AVEngineKit avEngineKit = a.ib;
