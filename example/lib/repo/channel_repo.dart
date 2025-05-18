import 'dart:async';

import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';

class ChannelRepo {
  static final Map<String, ChannelInfo> _channelMap = {};

  static StreamSubscription? _channelInfoUpdateSubscription;

  static void init() {
    _channelInfoUpdateSubscription?.cancel();
    _channelInfoUpdateSubscription = Imclient.IMEventBus.on<ChannelInfoUpdateEvent>().listen((event) {
      final List<ChannelInfo> updatedChannelInfos = event.channelInfos;

      for (var channelInfo in updatedChannelInfos) {
        if (channelInfo.updateDt > 0) {
          _channelMap[channelInfo.channelId] = channelInfo;
        }
      }
    });
  }

  static void clear() {
    _channelMap.clear();
  }

  static void dispose() {
    clear();
    _channelInfoUpdateSubscription?.cancel();
    _channelInfoUpdateSubscription = null;
  }

  static Future<ChannelInfo?> getChannelInfo(String channelId) async {
    var info = _channelMap[channelId];
    if (info == null) {
      info = await Imclient.getChannelInfo(channelId);
      if (info != null) {
        _channelMap[channelId] = info;
      }
    }
    return info;
  }

  static void putChannelInfo(ChannelInfo groupInfo) {
    _channelMap[groupInfo.channelId] = groupInfo;
  }
}
