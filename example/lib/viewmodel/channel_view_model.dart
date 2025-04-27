import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';

class ChannelViewModel extends ChangeNotifier {
  static final Map<String, ChannelInfo> _channelInfoMap = {};

  late StreamSubscription<ChannelInfoUpdateEvent> _groupInfoUpdatedSubscription;

  ChannelViewModel() {
    _groupInfoUpdatedSubscription = Imclient.IMEventBus.on<ChannelInfoUpdateEvent>().listen((event) {
      for (var channel in event.channelInfos) {
        _channelInfoMap[channel.channelId] = channel;
      }
      notifyListeners();
    });
  }

  ChannelInfo? getChannelInfo(String groupId) {
    var groupInfo = _channelInfoMap[groupId];
    if (groupInfo != null) {
      return groupInfo;
    }
    Imclient.getChannelInfo(groupId).then((info) {
      if (info == null) {
        return;
      }
      _channelInfoMap[groupId] = info;
      notifyListeners();
    });
    return null;
  }

  @override
  void dispose() {
    super.dispose();
    _groupInfoUpdatedSubscription.cancel();
  }
}
