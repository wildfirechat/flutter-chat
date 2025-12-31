class WfcScheme {
  static const String qrCodePrefixPcSession = "wildfirechat://pcsession/";
  static const String qrCodePrefixUser = "wildfirechat://user/";
  static const String qrCodePrefixGroup = "wildfirechat://group/";
  static const String qrCodePrefixChannel = "wildfirechat://channel/";
  static const String qrCodePrefixConference = "wildfirechat://conference/";

  static String buildConferenceScheme(String conferenceId, String? password) {
    String value = qrCodePrefixConference + conferenceId;
    if (password != null && password.isNotEmpty) {
      value += "/?pwd=$password";
    }
    return value;
  }

  static String buildGroupScheme(String groupId, String? source) {
    String value = qrCodePrefixGroup + groupId;
    if (source != null && source.isNotEmpty) {
      value += "?from=$source";
    }
    return value;
  }
}
