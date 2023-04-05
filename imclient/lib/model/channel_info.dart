class ChannelInfo {
  ChannelInfo({this.status = 0, this.updateDt = 0});
  late String channelId;
  String? name;
  String? portrait;
  String? owner;
  String? desc;
  String? extra;
  String? secret;
  String? callback;

  int status;
  int updateDt;
}
