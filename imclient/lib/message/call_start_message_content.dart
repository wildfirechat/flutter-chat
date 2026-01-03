import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';


// ignore: non_constant_identifier_names
MessageContent CallStartMessageContentCreator() {
  return CallStartMessageContent();
}

const callStartContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_START,
    MessageFlag.PERSIST_AND_COUNT, CallStartMessageContentCreator);

enum CallStartEndStatus {
  kWFAVCallEndReasonUnknown,
  kWFAVCallEndReasonBusy,
  kWFAVCallEndReasonSignalError,
  kWFAVCallEndReasonHangup,
  kWFAVCallEndReasonMediaError,
  kWFAVCallEndReasonRemoteHangup,
  kWFAVCallEndReasonOpenCameraFailure,
  kWFAVCallEndReasonTimeout,
  kWFAVCallEndReasonAcceptByOtherClient,
  kWFAVCallEndReasonAllLeft,
  kWFAVCallEndReasonRemoteBusy,
  kWFAVCallEndReasonRemoteTimeout,
  kWFAVCallEndReasonRemoteNetworkError,
  kWFAVCallEndReasonRoomDestroyed,
  kWFAVCallEndReasonRoomNotExist,
  kWFAVCallEndReasonRoomParticipantsFull,
  kWFAVCallEndReasonInterrupted,
  kWFAVCallEndReasonRemoteInterrupted
}

class CallStartMessageContent extends MediaMessageContent {
  late String callId;
  List<String> ?targetIds;
  int? connectTime;
  int? endTime;

  /*
  CallStartEndStatus
   */
  int status = 0;
  int sdkType = 0;
  bool audioOnly = false;
  String pin = '';

  @override
  MessageContentMeta get meta => callStartContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      status = map['s']??0;
      sdkType = map['ty']??0;
      pin = map['p'] ?? '';
      if(map['a'] == null) {
        audioOnly = false;
      } else {
        audioOnly = map['a'] > 0;
      }
      connectTime = map['c'];
      endTime = map['e'];
      if(map['ts'] != null) {
        List<dynamic> ts = map['ts'];
       targetIds = [];
       for (String value in ts) {
         targetIds!.add(value);
       }
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.content = callId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({
      'c': connectTime??0,
      'e': endTime??0,
      's': status,
      'ty': sdkType,
      'a' : audioOnly ? 1: 0,
      'ts': targetIds??[],
      'p': pin
    })));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[音视频通话]';
  }
}
