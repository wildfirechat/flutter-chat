class Config {
  //IM服务地址，不能带HTTP头和端口
  static const String IM_Host = 'wildfirechat.net';

  //应用服务地址。默认应用服务端口为8888，建议上线前添加HTTPS支持，可以用NG之类工具。
  // static const String APP_Server_Address = 'http://wildfirechat.net:8888';
  static const String APP_Server_Address = 'https://app.wildfirechat.net';
  //应用服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? APP_Server_Backup_Address = null;

  //组织通讯录服务地址，如果没有部署，可以设置为null
  static String? ORG_SERVER_ADDRESS = "https://org.wildfirechat.net";
  //组织通讯录服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? ORG_SERVER_BACKUP_ADDRESS = null;

  /// 工作台页面地址
  /// 如果不想显示工作台，置为 '' 即可
  static String WORKSPACE_URL = "https://open.wildfirechat.cn/work.html";
  // 工作台备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? WORKSPACE_BACKUP_URL = null;

  // 语音转文字服务地址，如果没有部署语音转文字服务，或者不需要语音转文字的话，可置为 null
  static String ASR_SERVER = 'https://app.wildfirechat.net/asr/api/recognize';
  // 语音转文字服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? ASR_SERVER_BACKUP = null;

  // 接龙服务地址，如果需要接龙功能，请部署接龙服务并配置地址；如果不需要接龙功能，请置为 null
  static String? COLLECTION_SERVER_ADDRESS = "https://jielong.wildfirechat.net";
  // 接龙服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? COLLECTION_SERVER_BACKUP_ADDRESS = null;

  // 投票服务地址，如果需要投票功能，请部署投票服务并配置地址；如果不需要投票功能，请置为 null
  static String? POLL_SERVER_ADDRESS = "https://poll.wildfirechat.net";
  // 投票服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? POLL_SERVER_BACKUP_ADDRESS = null;

  // 网盘服务地址，如果需要网盘功能，请部署网盘服务并配置地址；如果不需要网盘功能，请置为 null
  static String? PAN_SERVER_ADDRESS = null;
  // 网盘服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? PAN_SERVER_BACKUP_ADDRESS = null;

  // 消息归档服务地址，如果需要消息归档功能，请部署归档服务并配置地址；如果不需要，请置为 null
  static String? ARCHIVE_SERVER_ADDRESS = null;
  // 消息归档服务备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? ARCHIVE_SERVER_BACKUP_ADDRESS = null;

  /// 音视频通话所用的turn server配置，详情参考 https://docs.wildfirechat.net/webrtc/
  static final ICE_SERVERS = [
    ["turn:turn.wildfirechat.net:3478", "wfchat", "wfchat123"]
  ];

  // AI机器人ID，可以在单聊或者群里@
  static final AI_ROBOTS = ["FireRobot"];

  // 拨号机器人ID，点击该机器人会话进入拨号界面。不需要时置为 null 或空字符串。
  static String? DIALIN_ROBOT_ID = null;

  // AI语音记录助手ID，在和该助手单聊中点击通话记录可查看语音记录。不需要时置为 null 或空字符串。
  static String? AI_MINUTES_ROBOT_ID = "robotminutes";

  // 语音记录查看页面地址，不需要时置为 null 或空字符串。
  static String? MINUTES_URL = "http://101.42.4.222:8883/index.html";
  // 语音记录查看页面备选地址，双网环境下使用。不需要双网时保持为 null。
  static String? MINUTES_BACKUP_URL = null;

  // 文件传输助手用户ID，服务器有个默认文件助手的机器人，如果修改它的ID，需要客户端和服务器数据库同步修改
  static const String FILE_TRANSFER_ID = "wfc_file_transfer";

  // 是否优先密码登录。true: 默认展示密码登录；false: 默认展示验证码登录。
  static const bool Prefer_Password_Login = false;

  // 发送日志命令，当发送此文本消息时，会把协议栈日志发送到当前会话中，为空字符串时关闭此功能。
  static const String Send_Log_Command = "*#marslog#";

  // 是否开启水印
  static const bool ENABLE_WATER_MARKER = true;

  // 是否开启滑动验证。如果关闭，需要在应用服务同步关闭。
  static const bool ENABLE_SLIDE_VERIFY = true;

  // 双网媒体地址前缀，用于头像/媒体类消息中的 URL 转换。
  // 只在双网环境下配置，不需要双网时保持为 null。
  static String? MAIN_MEDIA_URL_PREFIX = null;
  static String? BACKUP_MEDIA_URL_PREFIX = null;

  static const String defaultUserPortrait = 'assets/images/user_avatar_default.png';
  static const String defaultGroupPortrait = 'assets/images/group_avatar_default.png';
  static const String defaultChannelPortrait = 'assets/images/channel_avatar_default.png';

  // 用户协议地址
  static const String USER_AGREEMENT_URL = "https://example.com/user_agreement.html";

  //  隐私协议地址
  static const String PRIVACY_AGREEMENT_URL = "https://example.com/user_privacy.html";

  /// 根据主备地址选择服务地址。
  /// 当前 Flutter 版本暂不判断实际网络主备，未配置备选时返回主地址。
  static String? selectServer(String? main, String? backup) {
    if ((main == null || main.isEmpty) && (backup == null || backup.isEmpty)) {
      return null;
    }
    if (backup == null || backup.isEmpty) {
      return main;
    }
    if (main == null || main.isEmpty) {
      return backup;
    }
    // TODO: 双网环境下可结合网络状态选择主备
    return main;
  }

  static String get appServerAddress => selectServer(APP_Server_Address, APP_Server_Backup_Address) ?? APP_Server_Address;
  static String? get orgServerAddress => selectServer(ORG_SERVER_ADDRESS, ORG_SERVER_BACKUP_ADDRESS);
  static String? get collectionServerAddress => selectServer(COLLECTION_SERVER_ADDRESS, COLLECTION_SERVER_BACKUP_ADDRESS);
  static String? get pollServerAddress => selectServer(POLL_SERVER_ADDRESS, POLL_SERVER_BACKUP_ADDRESS);
  static String? get panServerAddress => selectServer(PAN_SERVER_ADDRESS, PAN_SERVER_BACKUP_ADDRESS);
  static String? get archiveServerAddress => selectServer(ARCHIVE_SERVER_ADDRESS, ARCHIVE_SERVER_BACKUP_ADDRESS);
  static String? get workspaceUrl => selectServer(WORKSPACE_URL, WORKSPACE_BACKUP_URL);
  static String? get asrServerUrl => selectServer(ASR_SERVER, ASR_SERVER_BACKUP);
  static String? get minutesUrl => selectServer(MINUTES_URL, MINUTES_BACKUP_URL);
}
