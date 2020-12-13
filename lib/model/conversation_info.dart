import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient/model/unread_count.dart';

class ConversationInfo {
  ConversationInfo(
      {this.timestamp = 0, this.isTop = false, this.isSilent = false});
  Conversation conversation;
  Message lastMessage;
  String draft;
  int timestamp;
  UnreadCount unreadCount;
  bool isTop;
  bool isSilent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationInfo &&
          runtimeType == other.runtimeType &&
          conversation == other.conversation &&
          lastMessage == other.lastMessage &&
          draft == other.draft &&
          timestamp == other.timestamp &&
          unreadCount == other.unreadCount &&
          isTop == other.isTop &&
          isSilent == other.isSilent;

  @override
  int get hashCode =>
      conversation.hashCode ^
      lastMessage.hashCode ^
      draft.hashCode ^
      timestamp.hashCode ^
      unreadCount.hashCode ^
      isTop.hashCode ^
      isSilent.hashCode;
}
