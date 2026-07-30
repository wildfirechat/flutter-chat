class ChannelMenu {
  String? menuId;

  /// 菜单类型:view(打开链接)/click(发送菜单事件)/miniprogram(小程序)
  String? type;
  String? name;
  String? key;
  String? url;
  String? mediaId;
  String? articleId;
  String? appId;
  String? appPage;
  String? extra;
  List<ChannelMenu>? subMenus;

  /// 与 Android/iOS/Web 端一致的菜单序列化格式,
  /// 频道菜单事件消息(ChannelMenuEventMessageContent)按此格式传输菜单。
  /// 与 Android 的 putOpt 语义一致:null 字段不落到 json 里。
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    void put(String key, String? value) {
      if (value != null) json[key] = value;
    }

    put('menuId', menuId);
    put('type', type);
    put('name', name);
    put('key', key);
    put('url', url);
    put('mediaId', mediaId);
    put('articleId', articleId);
    put('appId', appId);
    put('appPage', appPage);
    put('extra', extra);
    if (subMenus != null && subMenus!.isNotEmpty) {
      json['subMenus'] = subMenus!.map((sm) => sm.toJson()).toList();
    }
    return json;
  }

  static ChannelMenu fromJson(Map<dynamic, dynamic> json) {
    ChannelMenu menu = ChannelMenu();
    menu.menuId = json['menuId'];
    menu.type = json['type'];
    menu.name = json['name'];
    menu.key = json['key'];
    menu.url = json['url'];
    menu.mediaId = json['mediaId'];
    menu.articleId = json['articleId'];
    menu.appId = json['appId'];
    menu.appPage = json['appPage'];
    menu.extra = json['extra'];
    List<dynamic>? subMenus = json['subMenus'];
    if (subMenus != null && subMenus.isNotEmpty) {
      menu.subMenus = subMenus.map((sm) => ChannelMenu.fromJson(sm)).toList();
    }
    return menu;
  }
}

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

  List<ChannelMenu>? menus;

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
