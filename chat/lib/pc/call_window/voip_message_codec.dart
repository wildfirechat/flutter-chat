import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:avenginekit/messages/answer_message_content.dart';
import 'package:avenginekit/messages/bye_message_content.dart';
import 'package:avenginekit/messages/call_answer_t_message_content.dart';
import 'package:avenginekit/messages/call_modify_message_content.dart';
import 'package:avenginekit/messages/conference_change_mode_message_content.dart';
import 'package:avenginekit/messages/conference_command_message_content.dart';
import 'package:avenginekit/messages/conference_kickoff_member_message_content.dart';
import 'package:avenginekit/messages/join_call_request_message_content.dart';
import 'package:avenginekit/messages/mute_video_message_content.dart';
import 'package:avenginekit/messages/multi_call_ongoing_message_content.dart';
import 'package:avenginekit/messages/signal_message_content.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/call_add_participants_notificiation_content.dart';
import 'package:imclient/message/notification/conference_invite_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/message_payload.dart';

/// 用于主窗口和 Call 窗口之间传输 VOIP 消息的编解码器。
///
/// 由于 [MessageContent] 没有内建的跨 isolate 序列化能力，这里只处理
/// avenginekit 关心的 VOIP 消息类型，手动把 [MessagePayload] 与 Map 互转。
class VoipMessageCodec {
  static const String _tag = 'VoipMessageCodec';

  static Map<String, dynamic> encodeMessage(Message message) {
    final payload = message.content.encode();
    return {
      'messageId': message.messageId,
      'messageUid': message.messageUid,
      'conversation': _encodeConversation(message.conversation),
      'fromUser': message.fromUser,
      'toUsers': message.toUsers,
      'direction': message.direction.index,
      'status': message.status.index,
      'serverTime': message.serverTime,
      'localExtra': message.localExtra,
      'payload': _encodePayload(payload),
    };
  }

  static MessageContent decodeMessageContent(Map<String, dynamic> map) {
    final payload = _decodePayload(map);
    final content = _createContent(payload.contentType);
    content.decode(payload);
    return content;
  }

  static Message decodeMessage(Map<String, dynamic> map) {
    // 主窗口编码时用的是 'content'，早期代码用的是 'payload'，两边都兼容。
    final payloadMap = map['content'] as Map<String, dynamic>?
        ?? map['payload'] as Map<String, dynamic>?;
    if (payloadMap == null) {
      throw ArgumentError('voip message missing payload/content: $map');
    }
    final payload = _decodePayload(payloadMap);
    final content = _createContent(payload.contentType);
    content.decode(payload);

    final message = Message(
      messageId: map['messageId'] as int? ?? 0,
      messageUid: map['messageUid'] as int?,
    );
    final conversationMap = map['conversation'] as Map<String, dynamic>?;
    if (conversationMap == null) {
      throw ArgumentError('voip message missing conversation: $map');
    }
    message.conversation = _decodeConversation(conversationMap);
    message.fromUser = map['fromUser'] as String? ?? '';
    message.toUsers = (map['toUsers'] as List?)?.cast<String>();
    message.content = content;
    message.direction = MessageDirection.values[map['direction'] as int? ?? 0];
    message.status = MessageStatus.values[map['status'] as int? ?? 0];
    message.serverTime = map['serverTime'] as int? ?? 0;
    message.localExtra = map['localExtra'] as String?;
    return message;
  }

  static Map<String, dynamic> _encodeConversation(Conversation conversation) {
    return {
      'conversationType': conversation.conversationType.index,
      'target': conversation.target,
      'line': conversation.line,
    };
  }

  static Conversation _decodeConversation(Map<String, dynamic> map) {
    // 兼容 IM channel 的 proto map（key 为 type）和本地编码（key 为 conversationType）。
    final typeIndex = (map['conversationType'] as int?) ?? (map['type'] as int?) ?? 0;
    return Conversation(
      conversationType: ConversationType.values[typeIndex],
      target: map['target'] as String? ?? '',
      line: map['line'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _encodePayload(MessagePayload payload) {
    return {
      'contentType': payload.contentType,
      'searchableContent': payload.searchableContent,
      'pushContent': payload.pushContent,
      'pushData': payload.pushData,
      'content': payload.content,
      'binaryContent': payload.binaryContent != null
          ? base64Encode(payload.binaryContent!)
          : null,
      'localContent': payload.localContent,
      'mentionedType': payload.mentionedType,
      'mentionedTargets': payload.mentionedTargets,
      'mediaType': payload.mediaType.index,
      'remoteMediaUrl': payload.remoteMediaUrl,
      'localMediaPath': payload.localMediaPath,
      'extra': payload.extra,
    };
  }

  static MessagePayload _decodePayload(Map<String, dynamic> map) {
    final payload = MessagePayload();
    // 兼容 IM channel 的 proto map（key 为 type）和本地 payload map（key 为 contentType）。
    payload.contentType = (map['contentType'] as int?) ?? (map['type'] as int?) ?? 0;
    payload.searchableContent = map['searchableContent'] as String?;
    payload.pushContent = map['pushContent'] as String?;
    payload.pushData = map['pushData'] as String?;
    payload.content = map['content'] as String?;
    final binary = map['binaryContent'];
    if (binary is Uint8List) {
      payload.binaryContent = binary;
    } else if (binary is List) {
      payload.binaryContent = Uint8List.fromList(List<int>.from(binary));
    } else if (binary is String) {
      payload.binaryContent = base64Decode(binary);
    } else if (binary != null) {
      log('VoipMessageCodec unexpected binary type: ${binary.runtimeType}');
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

  static MessageContent _createContent(int contentType) {
    final creator = _contentCreators[contentType];
    if (creator != null) return creator();
    log('$_tag unknown voip content type $contentType, fallback to empty content');
    return _TextLikeContent(contentType);
  }

  static final Map<int, MessageContent Function()> _contentCreators = {
    VOIP_CONTENT_TYPE_START: () => CallStartMessageContent(),
    VOIP_CONTENT_TYPE_END: () => ByeMessageContent(callId: ''),
    VOIP_CONTENT_TYPE_ACCEPT: () => AnswerMessageContent(callId: ''),
    VOIP_CONTENT_TYPE_ACCEPT_T: () => CallAnswerTMessageContent(),
    VOIP_CONTENT_TYPE_SIGNAL: () => SignalMessageContent(callId: '', payload: ''),
    VOIP_CONTENT_TYPE_MODIFY: () => CallModifyMessageContent(),
    VOIP_CONTENT_TYPE_ADD_PARTICIPANT: () => CallAddParticipantsNotificationContent(),
    VOIP_CONTENT_MUTE_VIDEO: () => MuteVideoMessageContent(),
    VOIP_CONTENT_CONFERENCE_INVITE: () => ConferenceInviteMessageContent(),
    VOIP_CONTENT_CONFERENCE_CHANGE_MODE: () => ConferenceChangeModeMessageContent(),
    VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER: () => ConferenceKickoffMemberMessageContent(),
    VOIP_CONTENT_CONFERENCE_COMMAND: () => ConferenceCommandMessageContent(),
    VOIP_CONTENT_MULTI_CALL_ONGOING: () => MultiCallOngoingMessageContent(),
    VOIP_CONTENT_JOIN_CALL_REQUEST: () => JoinCallRequestMessageContent(),
  };
}

/// 兜底占位内容，仅保留 contentType，避免未知消息崩溃。
class _TextLikeContent extends MessageContent {
  final int _type;
  _TextLikeContent(this._type);

  @override
  MessageContentMeta get meta => MessageContentMeta(_type, MessageFlag.TRANSPARENT, () => _TextLikeContent(_type));

  @override
  Future<String> digest(Message message) async => '未知通话消息';
}
