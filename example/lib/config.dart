class Config {
  //IM服务地址，不能带HTTP头和端口
  static const String IM_Host = 'wildfirechat.net';

  //应用服务地址。默认应用服务端口为8888，建议上线前添加HTTPS支持，可以用NG之类工具。
  // static const String APP_Server_Address = 'http://wildfirechat.net:8888';
  static const String APP_Server_Address = 'https://app.wildfirechat.net';

  /// 音视频通话所用的turn server配置，详情参考 https://docs.wildfirechat.net/webrtc/
  /// <br>
  /// <br>
  /// 单人版和多人版音视频必须部署turn服务。高级版不需要部署stun/turn服务。
  /// <p>
  /// !!! 我们提供的服务仅供用户测试和体验，为了保证测试可用，我们会不定期的更改密码. !!!
  /// <br>
  /// <strong>上线商用时，请更换为自己部署的turn 服务</strong>
  /// <br>
  static final ICE_SERVERS/*请仔细阅读上面的注释*/ =[
  // 数组元素定义
  /*{"turn server uri", "userName", "password"}*/
  ["turn:turn.wildfirechat.net:3478", "wfchat", "wfchat1"]
  ];

  static const String defaultUserPortrait = 'assets/images/user_avatar_default.png';
  static const String defaultGroupPortrait = 'assets/images/group_avatar_default.png';
  static const String defaultChannelPortrait = 'assets/images/channel_avatar_default.png';
}
