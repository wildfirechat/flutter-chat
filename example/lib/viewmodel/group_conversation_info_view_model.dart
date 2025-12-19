import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

import 'package:wfc_example/app_server.dart';

class GroupConversationInfoViewModel extends ChangeNotifier {
  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;

  bool _isFavGroup = false;
  GroupMember? _groupMember;
  String? _groupAnnouncement;

  GroupConversationInfoViewModel();

  bool get isFavGroup => _isFavGroup;

  GroupMember? get groupMember => _groupMember;

  String? get groupAnnouncement => _groupAnnouncement;

  void setup(String groupId) async {
    _isFavGroup = await Imclient.isFavGroup(groupId);
    _groupMember = await Imclient.getGroupMember(groupId, Imclient.currentUserId);
    _loadGroupAnnouncement(groupId);
    _groupMembersUpdatedSubscription = Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      if (event.groupId == groupId) {
        for (var member in event.members) {
          if (member.memberId == Imclient.currentUserId) {
            _groupMember = member;
            notifyListeners();
            break;
          }
        }
      }
    });
    notifyListeners();
  }

  void _loadGroupAnnouncement(String groupId) {
    AppServer.getGroupAnnouncement(groupId, (announcement) {
      _groupAnnouncement = announcement;
      notifyListeners();
    }, (msg) {
      // ignore error
    });
  }

  void refreshGroupAnnouncement(String groupId) {
    _loadGroupAnnouncement(groupId);
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
