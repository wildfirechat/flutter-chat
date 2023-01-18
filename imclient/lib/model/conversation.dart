enum ConversationType { Single, Group, Chatroom, Channel, Things }

class Conversation {
  Conversation(
      {this.conversationType = ConversationType.Single,
      this.target = '',
      this.line = 0});
  ConversationType conversationType;
  String target;
  int line;

  @override
  String toString() {
    return 'Conversation{conversationType: $conversationType, target: $target, line: $line}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          conversationType == other.conversationType &&
          target == other.target &&
          line == other.line;

  @override
  int get hashCode =>
      conversationType.hashCode ^ target.hashCode ^ line.hashCode;
}
