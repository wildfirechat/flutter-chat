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

  GroupInfo? getGroupInfo(String groupId) {
    var groupInfo = _groupInfoMap[groupId];
    if (groupInfo != null) {
      return groupInfo;
    }
    Imclient.getGroupInfo(groupId).then((info) {
      if (info == null) {
        return;
      }
      _groupInfoMap[groupId] = info;
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
