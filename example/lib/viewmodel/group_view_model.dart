import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';

class GroupViewModel extends ChangeNotifier {
  static final Map<String, GroupInfo> _groupInfoMap = {};

  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;

  GroupViewModel() {
    _groupInfoUpdatedSubscription = Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      for (var user in event.groupInfos) {
        _groupInfoMap[user.target] = user;
      }
      notifyListeners();
    });
  }

  Future<GroupInfo?> getGroupInfo(String groupId) async {
    var groupInfo = _groupInfoMap[groupId];
    if (groupInfo != null) {
      return groupInfo;
    }
    groupInfo = await Imclient.getGroupInfo(groupId);
    if (groupInfo == null) {
      return null;
    }
    _groupInfoMap[groupId] = groupInfo;
    notifyListeners();
    return groupInfo;
  }

  @override
  void dispose() {
    super.dispose();
    _groupInfoUpdatedSubscription.cancel();
  }
}
