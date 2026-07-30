import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/utils/media_url_redirector.dart';

class WFPortraitProvider extends DefaultPortraitProvider {
  WFPortraitProvider._internal();

  static WFPortraitProvider? _instance;

  static get instance {
    _instance ??= WFPortraitProvider._internal();
    return _instance;
  }

  @override
  String? groupDefaultPortrait(GroupInfo groupInfo, List<UserInfo> userInfos) {
    if ((groupInfo.portrait != null && groupInfo.portrait!.isNotEmpty) ||
        userInfos.isEmpty) {
      return groupInfo.portrait;
    } else {
      List<Map<String, String>> reqMembers = [];
      for (var userInfo in userInfos) {
        if (userInfo.portrait != null &&
            userInfo.portrait!.isNotEmpty &&
            !userInfo.portrait!.contains("avatar?name=")) {
          reqMembers.add({"avatarUrl": userInfo.portrait!});
        } else {
          reqMembers.add({"name": userInfo.displayName!});
        }
      }
      String jsonStr = jsonEncode({"members": reqMembers});
      return MediaUrlRedirector.redirect(
          '${Config.appServerAddress}/avatar/group?request=$jsonStr');
    }
  }

  @override
  String userDefaultPortrait(UserInfo userInfo) {
    if (userInfo.portrait != null && userInfo.portrait!.isNotEmpty) {
      return userInfo.portrait!;
    } else {
      return MediaUrlRedirector.redirect(
          '${Config.appServerAddress}/avatar?name=${userInfo.displayName}');
    }
  }
}
