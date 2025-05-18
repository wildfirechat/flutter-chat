import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/repo/group_repo.dart';

class GroupViewModel extends ChangeNotifier {
  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;

  GroupViewModel() {
    _groupInfoUpdatedSubscription = Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      GroupRepo.updateGroupInfos(event.groupInfos);
      notifyListeners();
    });
  }

  GroupInfo? getGroupInfo(String groupId) {
    var groupInfo = GroupRepo.getGroupInfo(groupId);
    if (groupInfo == null) {
      Imclient.getGroupInfo(groupId).then((info) {
        if (info != null && info.updateDt > 0) {
          GroupRepo.putGroupInfo(info);
          notifyListeners();
        }
      });
    }
    return groupInfo;
  }

  @override
  void dispose() {
    super.dispose();
    _groupInfoUpdatedSubscription.cancel();
  }
}
