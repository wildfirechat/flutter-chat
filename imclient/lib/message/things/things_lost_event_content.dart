import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ThingsLostEventContentCreator() {
  return ThingsLostEventContent();
}

const thingsLostEventContentMeta = MessageContentMeta(
  THINGS_CONTENT_TYPE_LOST_EVENT,
  MessageFlag.PERSIST,
  ThingsLostEventContentCreator,
);

/// 物联网设备丢失事件消息内容
///
/// 当物联网设备离线或丢失时产生的事件
/// 消息类型: 602
class ThingsLostEventContent extends MessageContent {
  /// 设备ID
  String deviceId = '';

  /// 丢失原因
  String reason = '';

  /// 丢失时间戳
  int lostTime = 0;

  @override
  MessageContentMeta get meta => thingsLostEventContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    deviceId = payload.searchableContent ?? '';
    reason = payload.content ?? '';
    lostTime = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = deviceId;
    payload.content = reason;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[设备丢失] $deviceId';
  }
}
