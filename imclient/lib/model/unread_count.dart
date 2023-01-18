class UnreadCount {
  UnreadCount(
      {this.unread = 0, this.unreadMention = 0, this.unreadMentionAll = 0});
  int unread;
  int unreadMention;
  int unreadMentionAll;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadCount &&
          runtimeType == other.runtimeType &&
          unread == other.unread &&
          unreadMention == other.unreadMention &&
          unreadMentionAll == other.unreadMentionAll;

  @override
  int get hashCode =>
      unread.hashCode ^ unreadMention.hashCode ^ unreadMentionAll.hashCode;
}
