class OnlineInfo {
  OnlineInfo(
      {this.type = 0,
      this.isOnline = false,
      this.platform = 0,
      this.timestamp = 0});
  //0 pc; 1 web; 2 micro app
  int type;
  bool isOnline;
  int /*WFCCPlatformType*/ platform;
  String clientId;
  String clientName;
  int timestamp;
}
