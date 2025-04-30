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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is ChannelInfo &&
          runtimeType == other.runtimeType &&
          channelId == other.channelId &&
          updateDt == other.updateDt);

  @override
  int get hashCode =>
      channelId.hashCode ^
      name.hashCode ^
      portrait.hashCode ^
      owner.hashCode ^
      desc.hashCode ^
      extra.hashCode ^
      secret.hashCode ^
      callback.hashCode ^
      status.hashCode ^
      updateDt.hashCode;
}
