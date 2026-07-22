import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

import 'package:chat/app_server.dart';
import 'package:chat/group/fav_group_event.dart';

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
    try {
      _isFavGroup = await Imclient.isFavGroup(groupId);
      _groupMember = await Imclient.getGroupMember(groupId, Imclient.currentUserId);
      debugPrint('[GroupConvInfo] group=$groupId currentUserId=${Imclient.currentUserId} localMember=${_groupMember == null ? "null" : "ok"}');
      if (_groupMember == null) {
        // 本地没有自己的群成员记录（群成员数据尚未同步）时页面会一直停在
        // 加载中，从服务器刷新一次群成员再查。
        await Imclient.getGroupMembers(groupId, refresh: true);
        _groupMember = await Imclient.getGroupMember(groupId, Imclient.currentUserId);
        debugPrint('[GroupConvInfo] group=$groupId memberAfterRefresh=${_groupMember == null ? "still null" : "ok"}');
      }
    } catch (e, s) {
      debugPrint('[GroupConvInfo] setup error: $e\n$s');
    }
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
      Imclient.IMEventBus.fire(FavGroupUpdatedEvent(groupId, fav));
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
