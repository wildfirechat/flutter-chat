
class ClientState {
  int platform;
  int state;
  int lastSeen;

  ClientState(this.platform, this.state, this.lastSeen);
}

class CustomState {
  int state;
  String? text;

  CustomState(this.state);
}

class UserOnlineState {
  String userId;
  List<ClientState>? clientStates;
  CustomState? customState;

  UserOnlineState(this.userId);
}