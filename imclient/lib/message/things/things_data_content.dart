import 'dart:typed_data';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ThingsDataContentCreator() {
  return ThingsDataContent();
}

const thingsDataContentMeta = MessageContentMeta(
  THINGS_CONTENT_TYPE_DATA,
  MessageFlag.PERSIST,
  ThingsDataContentCreator,
);

/// 物联网数据消息内容
///
/// 用于物联网设备向服务器上报数据
/// 消息类型: 601
class ThingsDataContent extends MessageContent {
  /// 设备ID
  String deviceId = '';

  /// 数据内容（二进制）
  Uint8List? data;

  @override
  MessageContentMeta get meta => thingsDataContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    deviceId = payload.searchableContent ?? '';
    data = payload.binaryContent;
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = deviceId;
    payload.binaryContent = data;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[IoT数据]';
  }
}
