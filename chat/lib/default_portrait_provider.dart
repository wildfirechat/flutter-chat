import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';

class WFPortraitProvider extends DefaultPortraitProvider {
  WFPortraitProvider._internal();

  static WFPortraitProvider? _instance;

  static get instance {
    _instance ??= WFPortraitProvider._internal();
    return _instance;
  }

  @override
  String? groupDefaultPortrait(GroupInfo groupInfo, List<UserInfo> userInfos) {
    if ((groupInfo.portrait != null && groupInfo.portrait!.isNotEmpty) || userInfos.isEmpty) {
      return groupInfo.portrait;
    } else {
      List<Map<String, String>> reqMembers = [];
      for (var userInfo in userInfos) {
        if (userInfo.portrait != null && userInfo.portrait!.isNotEmpty && !userInfo.portrait!.contains("avatar?name=")) {
          reqMembers.add({"avatarUrl": userInfo.portrait!});
        } else {
          reqMembers.add({"name": userInfo.displayName!});
        }
      }
      String jsonStr = jsonEncode({"members": reqMembers});
      return '${Config.APP_Server_Address}/avatar/group?request=$jsonStr';
    }
  }

  @override
  String userDefaultPortrait(UserInfo userInfo) {
    if (userInfo.portrait != null && userInfo.portrait!.isNotEmpty) {
      return userInfo.portrait!;
    } else {
      return '${Config.APP_Server_Address}/avatar?name=${userInfo.displayName}';
    }
  }
}
