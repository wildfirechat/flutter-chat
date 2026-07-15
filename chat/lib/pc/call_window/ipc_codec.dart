import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/message_payload.dart';

/// 主/子窗口 IPC 的纯数据编解码,是跨窗口线格式的唯一定义处。
///
/// 线格式与 imclient 的 proto map 保持一致:payload 用 'type' key、
/// binaryContent 编码为 base64、conversation 用 'type' key。这样子窗口把
/// 主窗口返回的 map 直接交给 ImclientPlatform 的 _convertProtoXxx 即可解析,
/// SDK 层无需感知 IPC 的存在。
///
/// binaryContent 解码兼容三种形态:Uint8List(同 isolate)、List<int>
/// (MethodChannel 透传后 Uint8List 常被重建为 List<dynamic>)、base64 字符串
/// (本 codec 编码产物)。
class IpcCodec {
  static Map<String, dynamic> encodeConversation(Conversation conversation) {
    return {
      'type': conversation.conversationType.index,
      'target': conversation.target,
      'line': conversation.line,
    };
  }

  static Conversation decodeConversation(Map<dynamic, dynamic> map) {
    return Conversation(
      conversationType: ConversationType.values[map['type'] as int? ?? 0],
      target: map['target'] as String? ?? '',
      line: map['line'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> encodeMessage(Message message) {
    return {
      'messageId': message.messageId,
      'messageUid': message.messageUid,
      'conversation': encodeConversation(message.conversation),
      'fromUser': message.fromUser,
      'toUsers': message.toUsers,
      'direction': message.direction.index,
      'status': message.status.index,
      'serverTime': message.serverTime,
      'localExtra': message.localExtra,
      'content': encodePayload(message.content.encode()),
    };
  }

  static Map<String, dynamic> encodePayload(MessagePayload payload) {
    return {
      'type': payload.contentType,
      'searchableContent': payload.searchableContent,
      'pushContent': payload.pushContent,
      'pushData': payload.pushData,
      'content': payload.content,
      'binaryContent': payload.binaryContent != null ? base64Encode(payload.binaryContent!) : null,
      'localContent': payload.localContent,
      'mentionedType': payload.mentionedType,
      'mentionedTargets': payload.mentionedTargets,
      'mediaType': payload.mediaType.index,
      'remoteMediaUrl': payload.remoteMediaUrl,
      'localMediaPath': payload.localMediaPath,
      'extra': payload.extra,
    };
  }

  static MessagePayload decodePayload(Map<dynamic, dynamic> map) {
    final payload = MessagePayload();
    payload.contentType = map['type'] as int? ?? 0;
    payload.searchableContent = map['searchableContent'] as String?;
    payload.pushContent = map['pushContent'] as String?;
    payload.pushData = map['pushData'] as String?;
    payload.content = map['content'] as String?;
    final binary = map['binaryContent'];
    if (binary is Uint8List) {
      payload.binaryContent = binary;
    } else if (binary is List) {
      payload.binaryContent = Uint8List.fromList(List<int>.from(binary));
    } else if (binary is String && binary.isNotEmpty) {
      payload.binaryContent = base64Decode(binary);
    } else if (binary != null) {
      log('IpcCodec unexpected binaryContent type: ${binary.runtimeType}');
    }
    payload.localContent = map['localContent'] as String?;
    payload.mentionedType = map['mentionedType'] as int? ?? 0;
    payload.mentionedTargets = (map['mentionedTargets'] as List?)?.cast<String>();
    payload.mediaType = MediaType.values[map['mediaType'] as int? ?? 0];
    payload.remoteMediaUrl = map['remoteMediaUrl'] as String?;
    payload.localMediaPath = map['localMediaPath'] as String?;
    payload.extra = map['extra'] as String?;
    return payload;
  }
}
