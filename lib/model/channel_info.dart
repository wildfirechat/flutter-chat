enum ChannelStatus {
  Public,
  Private,
  Destroyed,
}

class ChannelInfo {
  ChannelInfo({this.status = ChannelStatus.Public, this.updateDt = 0});
  String channelId;
  String name;
  String portrait;
  String owner;
  String desc;
  String extra;
  String secret;
  String callback;

  ChannelStatus status;
  int updateDt;
}
