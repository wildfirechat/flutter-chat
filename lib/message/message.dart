import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/conversation.dart';

enum MessageStatus {
  ///消息发送中
  Message_Status_Sending,

  ///消息已发送
  Message_Status_Sent,

  ///消息发送失败
  Message_Status_Send_Failure,

  ///消息@当前用户
  Message_Status_Mentioned,

  ///消息@全体用户
  Message_Status_AllMentioned,

  ///消息未读
  Message_Status_Unread,

  ///消息已读
  Message_Status_Readed,

  ///消息已播放
  Message_Status_Played
}

enum MessageDirection { MessageDirection_Send, MessageDirection_Receive }

class Message {
  int messageId;
  int messageUid;
  Conversation conversation;
  String fromUser;
  List<String> toUsers;
  MessageContent content;
  MessageDirection direction;
  MessageStatus status;
  int serverTime;

  @override
  String toString() {
    return 'Message{messageId: $messageId, messageUid: $messageUid, conversation: $conversation, fromUser: $fromUser, toUsers: $toUsers, content: $content, direction: $direction, status: $status, serverTime: $serverTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          messageUid == other.messageUid &&
          conversation == other.conversation &&
          fromUser == other.fromUser &&
          toUsers == other.toUsers &&
          content == other.content &&
          direction == other.direction &&
          status == other.status &&
          serverTime == other.serverTime;

  @override
  int get hashCode =>
      messageId.hashCode ^
      messageUid.hashCode ^
      conversation.hashCode ^
      fromUser.hashCode ^
      toUsers.hashCode ^
      content.hashCode ^
      direction.hashCode ^
      status.hashCode ^
      serverTime.hashCode;
}
