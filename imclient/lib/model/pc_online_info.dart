class PCOnlineInfo {
  PCOnlineInfo(
      {this.platform = 0,
      this.type = 0,
      this.isOnline = false,
      this.timestamp = 0});

  /// 多端在线类型,与服务端/原生(HarmonyOS PCOnlineInfo)对齐:
  /// 0 PC / 1 Web / 2 微信小程序 / 3 Pad / 4 手表 / 5 电视
  static const int pcOnline = 0;
  static const int webOnline = 1;
  static const int wxOnline = 2;
  static const int padOnline = 3;
  static const int wearableOnline = 4;
  static const int tvOnline = 5;

  /// 多端在线类型,见 [pcOnline] ~ [tvOnline]。
  int type;
  bool isOnline;
  int /*WFCCPlatformType*/ platform;
  late String clientId;
  String? clientName;
  int timestamp;
}
