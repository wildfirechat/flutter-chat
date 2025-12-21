import 'dart:io';

class Config {
  //IM服务地址，不能带HTTP头和端口
  static const String IM_Host = 'wildfirechat.net';

  //应用服务地址。默认应用服务端口为8888，建议上线前添加HTTPS支持，可以用NG之类工具。
  // static const String APP_Server_Address = 'http://wildfirechat.net:8888';
  static const String APP_Server_Address = 'https://app.wildfirechat.net';

  //组织通讯录服务地址，如果没有部署，可以设置为null
  static String? ORG_SERVER_ADDRESS = "https://org.wildfirechat.cn"; // Example: replace with your actual org server address

  /// 工作台页面地址
  /// <p>
  /// 如果不想显示工作台，置为 '' 即可
  /// static String WORKSPACE_URL = "https://open.wildfirechat.cn/work.html";
  /// 鸿蒙暂不支持
  static String WORKSPACE_URL = ['android', 'ios'].contains(Platform.operatingSystem) ? "https://open.wildfirechat.cn/work.html" : "";

  /// 音视频通话所用的turn server配置，详情参考 https://docs.wildfirechat.net/webrtc/
  /// <br>
  /// <br>
  /// 单人版和多人版音视频必须部署turn服务。高级版不需要部署stun/turn服务。
  /// <p>
  /// !!! 我们提供的服务能力有限，总体带宽仅3Mbps，只能用于用户测试和体验，为了保证测试可用，我们会不定期的更改密码. !!!
  /// <br>
  /// <strong>上线时请一定要切换成你们自己的服务。可以购买腾讯云或者阿里云的轻量服务器，价格很便宜，可以避免影响到您的用户体验。</strong>
  /// <br>
  static final ICE_SERVERS /*请仔细阅读上面的注释*/ = [
    // 数组元素定义
    /*{"turn server uri", "userName", "password"}*/
    ["turn:turn.wildfirechat.net:3478", "wfchat", "wfchat123"]
  ];

  // AI机器人ID
  static final AI_ROBOTS = ["FireRobot"];

  static const String defaultUserPortrait = 'assets/images/user_avatar_default.png';
  static const String defaultGroupPortrait = 'assets/images/group_avatar_default.png';
  static const String defaultChannelPortrait = 'assets/images/channel_avatar_default.png';
}
