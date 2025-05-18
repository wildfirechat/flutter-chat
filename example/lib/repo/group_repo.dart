import 'dart:async';

import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';

class GroupRepo {
  static final Map<String, GroupInfo> _groupMap = {};
  static StreamSubscription? _groupInfoUpdateSubscription;

  static void init() {
    _groupInfoUpdateSubscription?.cancel();
    _groupInfoUpdateSubscription = Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      final List<GroupInfo> updatedGroupInfos = event.groupInfos;

      for (var groupInfo in updatedGroupInfos) {
        if (groupInfo.updateDt > 0) {
          _groupMap[groupInfo.target] = groupInfo;
        }
      }
    });
  }

  static void clear() {
    _groupMap.clear();
  }

  static void dispose() {
    clear();
    _groupInfoUpdateSubscription?.cancel();
    _groupInfoUpdateSubscription = null;
  }

  static Future<GroupInfo?> getGroupInfo(String groupId) async {
    var info = _groupMap[groupId];
    if (info == null) {
      info = await Imclient.getGroupInfo(groupId);
      if (info != null) {
        _groupMap[groupId] = info;
      }
    }
    return info;
  }

  static Future<List<GroupInfo>> getGroupInfos(List<String> groupIds) async {
    var infos = await Imclient.getGroupInfos(groupIds);
    for (var info in infos) {
      if (info.updateDt > 0) {
        _groupMap[info.target] = info;
      }
    }
    return infos;
  }
}
