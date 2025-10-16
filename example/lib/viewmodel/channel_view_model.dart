import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:wfc_example/repo/channel_repo.dart';

class ChannelViewModel extends ChangeNotifier {
  late StreamSubscription<ChannelInfoUpdateEvent> _channelInfoUpdatedSubscription;

  ChannelViewModel() {
    _channelInfoUpdatedSubscription = Imclient.IMEventBus.on<ChannelInfoUpdateEvent>().listen((event) {
      ChannelRepo.updateChannelInfos(event.channelInfos);
      notifyListeners();
    });
  }

  ChannelInfo? getChannelInfo(String channelId) {
    var channelInfo = ChannelRepo.getChannelInfo(channelId);
    if (channelInfo == null) {
      Imclient.getChannelInfo(channelId).then((info) {
        if (info != null && info.updateDt > 0) {
          ChannelRepo.putChannelInfo(info);
          notifyListeners();
        }
      });
    }
    return channelInfo;
  }

  @override
  void dispose() {
    super.dispose();
    _channelInfoUpdatedSubscription.cancel();
  }
}
