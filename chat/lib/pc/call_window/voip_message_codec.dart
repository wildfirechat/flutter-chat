import 'dart:developer';

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

import '../multi_window/ipc_codec.dart';

/// Call 窗口侧的 VOIP 消息解码器:线格式解析统一走 [IpcCodec],
/// 本类只负责按 contentType 实例化 avenginekit 的具体消息内容类。
class VoipMessageCodec {
  static const String _tag = 'VoipMessageCodec';

  static Message decodeMessage(Map<String, dynamic> map) {
    final payloadMap = map['content'] as Map<String, dynamic>?;
    if (payloadMap == null) {
      throw ArgumentError('voip message missing content: $map');
    }
    final payload = IpcCodec.decodePayload(payloadMap);
    final content = _createContent(payload.contentType);
    content.decode(payload);

    final conversationMap = map['conversation'] as Map<String, dynamic>?;
    if (conversationMap == null) {
      throw ArgumentError('voip message missing conversation: $map');
    }

    final message = Message(
      messageId: map['messageId'] as int? ?? 0,
      messageUid: map['messageUid'] as int?,
    );
    message.conversation = IpcCodec.decodeConversation(conversationMap);
    message.fromUser = map['fromUser'] as String? ?? '';
    message.toUsers = (map['toUsers'] as List?)?.cast<String>();
    message.content = content;
    message.direction = MessageDirection.values[map['direction'] as int? ?? 0];
    message.status = MessageStatus.values[map['status'] as int? ?? 0];
    message.serverTime = map['serverTime'] as int? ?? 0;
    message.localExtra = map['localExtra'] as String?;
    return message;
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
    VOIP_CONTENT_TYPE_SIGNAL: () =>
        SignalMessageContent(callId: '', payload: ''),
    VOIP_CONTENT_TYPE_MODIFY: () => CallModifyMessageContent(),
    VOIP_CONTENT_TYPE_ADD_PARTICIPANT: () =>
        CallAddParticipantsNotificationContent(),
    VOIP_CONTENT_MUTE_VIDEO: () => MuteVideoMessageContent(),
    VOIP_CONTENT_CONFERENCE_INVITE: () => ConferenceInviteMessageContent(),
    VOIP_CONTENT_CONFERENCE_CHANGE_MODE: () =>
        ConferenceChangeModeMessageContent(),
    VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER: () =>
        ConferenceKickoffMemberMessageContent(),
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
  MessageContentMeta get meta => MessageContentMeta(
      _type, MessageFlag.TRANSPARENT, () => _TextLikeContent(_type));

  @override
  Future<String> digest(Message message) async => '未知通话消息';
}
