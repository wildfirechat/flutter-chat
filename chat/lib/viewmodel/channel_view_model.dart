import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:chat/repo/channel_repo.dart';

class ChannelViewModel extends ChangeNotifier {
  late StreamSubscription<ChannelInfoUpdateEvent>
      _channelInfoUpdatedSubscription;

  ChannelViewModel() {
    _channelInfoUpdatedSubscription =
        Imclient.IMEventBus.on<ChannelInfoUpdateEvent>().listen((event) {
      ChannelRepo.updateChannelInfos(event.channelInfos);
      notifyListeners();
    });
  }

  void reset() {
    _fetchingChannelIds.clear();
    ChannelRepo.clear();
    notifyListeners();
  }

  /// 已发起过查询的频道。只有查询抛异常才移除 —— 原实现无论结果如何都移除,
  /// 频道信息查不到时会在每次列表重建时被反复查询。
  final Set<String> _fetchingChannelIds = {};

  ChannelInfo? getChannelInfo(String channelId) {
    var channelInfo = ChannelRepo.getChannelInfo(channelId);
    if (channelInfo == null && _fetchingChannelIds.add(channelId)) {
      Imclient.getChannelInfo(channelId).then((info) {
        if (info != null && info.updateDt > 0) {
          ChannelRepo.putChannelInfo(info);
          notifyListeners();
        }
      }).catchError((e) {
        _fetchingChannelIds.remove(channelId);
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
