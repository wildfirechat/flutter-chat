import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

class GroupViewModel extends ChangeNotifier {
  static final Map<String, GroupInfo> _groupInfoMap = {};

  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;

  GroupInfo? _groupInfo;
  bool _isFavGroup = false;
  bool _isHiddenMemberName = false;
  GroupMember? _groupMember;
  List<UserInfo> _groupMemberUserInfos = [];

  GroupViewModel() {
    _groupInfoUpdatedSubscription = Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      for (var info in event.groupInfos) {
        _groupInfoMap[info.target] = info;
      }
      notifyListeners();
    });
  }

  GroupInfo? get groupInfo => _groupInfo;

  bool get isFavGroup => _isFavGroup;

  bool get isHiddenMemberName => _isHiddenMemberName;

  GroupMember? get groupMember => _groupMember;

  List<UserInfo> get groupMemberUserInfos => _groupMemberUserInfos;

  void setup(String groupId) async {
    _groupInfo = await getGroupInfo(groupId);
    _isFavGroup = await Imclient.isFavGroup(groupId);
    _isHiddenMemberName = await Imclient.isHiddenGroupMemberName(groupId);
    _groupMember = await Imclient.getGroupMember(groupId, Imclient.currentUserId);
    var groupMemberIds = (await Imclient.getGroupMembers(groupId)).map((e) => e.memberId).toList();
    _groupMemberUserInfos = await Imclient.getUserInfos(groupMemberIds, groupId: groupId);
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
      _isHiddenMemberName = hide;
      notifyListeners();
    }, (errorCode) {});
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
