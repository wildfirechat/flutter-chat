class OnlineInfo {
  OnlineInfo(
      {this.platform = 0, this.type = 0,
      this.isOnline = false,
      this.timestamp = 0});
  //0 pc; 1 web; 2 micro app
  int type;
  bool isOnline;
  int /*WFCCPlatformType*/ platform;
  late String clientId;
  String? clientName;
  int timestamp;
}
