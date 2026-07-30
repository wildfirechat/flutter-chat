import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

import 'package:chat/app_server.dart';
import 'package:chat/group/fav_group_event.dart';

class GroupConversationInfoViewModel extends ChangeNotifier {
  // setup 中多个 await 之后才赋值，setup 完成前 dispose 不能触发 LateInitializationError
  StreamSubscription<GroupMembersUpdatedEvent>?
      _groupMembersUpdatedSubscription;

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
      // 进入群设置时强制同步一次群信息与群成员（refresh 触发服务器同步），
      // 避免本地数据缺失/过期导致页面一直停在加载中。
      await Future.wait([
        Imclient.getGroupInfo(groupId, refresh: true),
        Imclient.getGroupMembers(groupId, refresh: true),
      ]);
      _groupMember =
          await Imclient.getGroupMember(groupId, Imclient.currentUserId);
      debugPrint(
          '[GroupConvInfo] group=$groupId member=${_groupMember == null ? "null" : "ok"}');
    } catch (e, s) {
      debugPrint('[GroupConvInfo] setup error: $e\n$s');
    }
    _loadGroupAnnouncement(groupId);
    _groupMembersUpdatedSubscription =
        Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
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
    _groupMembersUpdatedSubscription?.cancel();
  }
}
