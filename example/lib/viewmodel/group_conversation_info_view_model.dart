import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

class GroupConversationInfoViewModel extends ChangeNotifier {
  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;

  bool _isFavGroup = false;
  GroupMember? _groupMember;

  GroupConversationInfoViewModel();

  bool get isFavGroup => _isFavGroup;

  GroupMember? get groupMember => _groupMember;

  void setup(String groupId) async {
    _isFavGroup = await Imclient.isFavGroup(groupId);
    _groupMember = await Imclient.getGroupMember(groupId, Imclient.currentUserId);
    notifyListeners();
  }

  void setFavGroup(String groupId, bool fav) {
    Imclient.setFavGroup(groupId, fav, () {
      _isFavGroup = fav;
      notifyListeners();
    }, (errorCode) {});
  }

  void setHideGroupMemberName(String groupId, bool hide) {
    Imclient.setHiddenGroupMemberName(groupId, hide, () {
      notifyListeners();
    }, (errorCode) {});
  }

  @override
  void dispose() {
    super.dispose();
    _groupMembersUpdatedSubscription.cancel();
  }
}
