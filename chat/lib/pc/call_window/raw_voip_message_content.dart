import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

/// 主窗口用来“占位”所有 VOIP 消息类型的通用内容类。
///
/// 主窗口不需要理解音视频业务，只要能把 VOIP 消息原样透传给 Call 窗口即可。
/// 这里只按类型保留原始 [MessagePayload]，并注册正确的 [MessageFlag]，
/// 让 IM SDK 对 incoming VOIP 消息的处理（是否存储/计数）与 avenginekit 一致。
class RawVoipMessageContent extends MessageContent {
  RawVoipMessageContent(this._type, this._flag);

  final int _type;
  final MessageFlag _flag;
  MessagePayload? _payload;

  factory RawVoipMessageContent.fromMap(Map<String, dynamic> map) {
    final type = (map['contentType'] as int?) ?? (map['type'] as int?) ?? 0;
    final flag = _voipFlags[type] ?? MessageFlag.NOT_PERSIST;
    final content = RawVoipMessageContent(type, flag);
    content._payload = _payloadFromMap(map);
    return content;
  }

  @override
  MessageContentMeta get meta => MessageContentMeta(
        _type,
        _flag,
        () => RawVoipMessageContent(_type, _flag),
      );

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    _payload = payload;
  }

  @override
  MessagePayload encode() {
    if (_payload == null) {
      final fallback = MessagePayload();
      fallback.contentType = _type;
      fallback.mediaType = MediaType.Media_Type_GENERAL;
      return fallback;
    }
    return _payload!;
  }

  @override
  Future<String> digest(Message message) async {
    if (_type == VOIP_CONTENT_TYPE_START && _payload?.binaryContent != null) {
      try {
        final map = json.decode(utf8.decode(_payload!.binaryContent!)) as Map<String, dynamic>;
        final audioOnly = (map['a'] as int? ?? 0) > 0;
        return audioOnly ? '[语音通话]' : '[视频通话]';
      } catch (e) {
        // fall through
      }
    }
    return _voipDigest[_type] ?? '通话消息';
  }

  static MessagePayload _payloadFromMap(Map<String, dynamic> map) {
    final payload = MessagePayload();
    payload.contentType = (map['contentType'] as int?) ?? (map['type'] as int?) ?? 0;
    payload.searchableContent = map['searchableContent'] as String?;
    payload.pushContent = map['pushContent'] as String?;
    payload.pushData = map['pushData'] as String?;
    payload.content = map['content'] as String?;
    final binary = map['binaryContent'];
    if (binary is Uint8List) {
      payload.binaryContent = binary;
    } else if (binary is List) {
      // MethodChannel/FFI 透传时 Uint8List 常被重新实例化为 List<dynamic>
      //（运行时类型如 _GrowableList），需要显式转回 Uint8List。
      payload.binaryContent = Uint8List.fromList(List<int>.from(binary));
    } else if (binary is String && binary.isNotEmpty) {
      payload.binaryContent = base64Decode(binary);
    } else if (binary != null) {
      log('RawVoipMessageContent unexpected binary type: ${binary.runtimeType}');
    }
    payload.localContent = map['localContent'] as String?;
    payload.mentionedType = (map['mentionedType'] as int?) ?? 0;
    payload.mentionedTargets = (map['mentionedTargets'] as List?)?.cast<String>();
    payload.mediaType = MediaType.values[(map['mediaType'] as int?) ?? 0];
    payload.remoteMediaUrl = map['remoteMediaUrl'] as String?;
    payload.localMediaPath = map['localMediaPath'] as String?;
    payload.extra = map['extra'] as String?;
    return payload;
  }
}

/// VOIP 消息类型 -> MessageFlag，需与 avenginekit 中各 meta 保持一致。
const Map<int, MessageFlag> _voipFlags = {
  VOIP_CONTENT_TYPE_START: MessageFlag.PERSIST_AND_COUNT,
  VOIP_CONTENT_TYPE_END: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_TYPE_ACCEPT: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_TYPE_ACCEPT_T: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_TYPE_SIGNAL: MessageFlag.TRANSPARENT,
  VOIP_CONTENT_TYPE_MODIFY: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_TYPE_ADD_PARTICIPANT: MessageFlag.PERSIST,
  VOIP_CONTENT_MUTE_VIDEO: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_CONFERENCE_INVITE: MessageFlag.PERSIST,
  VOIP_CONTENT_CONFERENCE_CHANGE_MODE: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_CONFERENCE_COMMAND: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_MULTI_CALL_ONGOING: MessageFlag.NOT_PERSIST,
  VOIP_CONTENT_JOIN_CALL_REQUEST: MessageFlag.NOT_PERSIST,
};

/// 主窗口会话列表里对 VOIP 消息的简短描述。
const Map<int, String> _voipDigest = {
  VOIP_CONTENT_TYPE_START: '[音视频通话]',
  VOIP_CONTENT_TYPE_END: '[通话结束]',
  VOIP_CONTENT_TYPE_ACCEPT: '[已接听]',
  VOIP_CONTENT_TYPE_ACCEPT_T: '[已接听]',
  VOIP_CONTENT_TYPE_SIGNAL: '[通话信令]',
  VOIP_CONTENT_TYPE_MODIFY: '[通话变更]',
  VOIP_CONTENT_TYPE_ADD_PARTICIPANT: '[邀请加入通话]',
  VOIP_CONTENT_MUTE_VIDEO: '[视频状态变更]',
  VOIP_CONTENT_CONFERENCE_INVITE: '[会议邀请]',
  VOIP_CONTENT_CONFERENCE_CHANGE_MODE: '[会议模式变更]',
  VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER: '[移出会议]',
  VOIP_CONTENT_CONFERENCE_COMMAND: '[会议命令]',
  VOIP_CONTENT_MULTI_CALL_ONGOING: '[多人通话中]',
  VOIP_CONTENT_JOIN_CALL_REQUEST: '[请求加入通话]',
};
