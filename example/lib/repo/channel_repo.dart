import 'dart:async';

import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';

class ChannelRepo {
  static final Map<String, ChannelInfo> _channelMap = {};

  static void clear() {
    _channelMap.clear();
  }

  static ChannelInfo? getChannelInfo(String channelId) {
    var info = _channelMap[channelId];
    return info;
  }

  static void putChannelInfo(ChannelInfo groupInfo) {
    _channelMap[groupInfo.channelId] = groupInfo;
  }

  static void updateChannelInfos(List<ChannelInfo> channelInfos) {
    for (var info in channelInfos) {
      if (info.updateDt > 0) {
        _channelMap[info.channelId] = info;
      }
    }
  }
}
