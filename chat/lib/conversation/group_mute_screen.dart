import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/mesh/mesh_cache.dart';

import '../contact/pick_user_screen.dart';
import '../pc/pc_platform.dart';
import '../pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_typography.dart';

class GroupMuteScreen extends StatefulWidget {
  final GroupInfo groupInfo;

  const GroupMuteScreen({super.key, required this.groupInfo});

  @override
  State<GroupMuteScreen> createState() => _GroupMuteScreenState();
}

class _GroupMuteScreenState extends State<GroupMuteScreen> {
  late GroupInfo _groupInfo;
  List<GroupMember> _members = [];
  Map<String, UserInfo> _userInfoMap = {};
  bool _loading = true;
  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;

  @override
  void initState() {
    super.initState();
    _groupInfo = widget.groupInfo;
    _loadMembers();
    _groupMembersUpdatedSubscription = Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      if (event.groupId == _groupInfo.target) {
        _loadMembers();
      }
    });
  }

  @override
  void dispose() {
    _groupMembersUpdatedSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    var members = await Imclient.getGroupMembers(_groupInfo.target);
    var memberIds = members.map((e) => e.memberId).toList();
    Map<String, UserInfo> userInfoMap = {};
    if (memberIds.isNotEmpty) {
      var userInfos = await Imclient.getUserInfos(memberIds, groupId: _groupInfo.target);
      for (var userInfo in userInfos) {
        userInfoMap[userInfo.userId] = userInfo;
      }
    }
    if (mounted) {
      setState(() {
        _members = members;
        _userInfoMap = userInfoMap;
        _loading = false;
      });
    }
  }

  List<GroupMember> get _mutedMembers {
    return _members.where((m) => m.type == GroupMemberType.Muted).toList();
  }

  List<GroupMember> get _allowedMembers {
    return _members.where((m) => m.type == GroupMemberType.Allowed).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: isDesktopShell
          ? const PcPageHeader(title: '禁言设置')
          : AppBar(
              title: Text(l10n.muteSetting),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  OptionSwitchItem(l10n.muteAllMembers, _groupInfo.mute == 1, (value) {
                    Imclient.modifyGroupInfo(
                      _groupInfo.target,
                      ModifyGroupInfoType.Modify_Group_Mute,
                      value ? "1" : "0",
                      () {
                        setState(() {
                          _groupInfo.mute = value ? 1 : 0;
                        });
                      },
                      (errorCode) {
                        Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
                      },
                    );
                  }),
                  _buildSectionHeader(l10n.mutedMembers),
                  ..._mutedMembers.map((member) => _buildMemberTile(context, member, () => _unmuteMember(member.memberId))),
                  _buildAddButton(l10n.addMutedMember, _addMutedMember),
                  _buildSectionHeader(l10n.allowedMembers),
                  ..._allowedMembers.map((member) => _buildMemberTile(context, member, () => _unallowMember(member.memberId))),
                  _buildAddButton(l10n.addAllowedMember, _addAllowedMember),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppText.sm.copyWith(color: Colors.grey),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, GroupMember member, VoidCallback onRemove) {
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        UserInfo? userInfo = _userInfoMap[member.memberId];
        return ListTile(
          leading: Portrait(userInfo?.portrait ?? '', Config.defaultUserPortrait, width: 44, height: 44, borderRadius: 6),
          title: userInfo != null ? MeshUserName(userInfo) : Text(member.memberId),
          trailing: TextButton(
            onPressed: onRemove,
            child: Text(
              AppLocalizations.of(context)!.remove,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton(String title, VoidCallback onTap) {
    return ListTile(
      leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
      title: Text(title, style: const TextStyle(color: Colors.blue)),
      onTap: onTap,
    );
  }

  void _addMutedMember() {
    _pickMembersAndAct(
      title: AppLocalizations.of(context)!.addMutedMember,
      targetType: GroupMemberType.Muted,
      action: (ids) => Imclient.muteGroupMember(_groupInfo.target, true, ids, () {}, (code) {}),
    );
  }

  void _addAllowedMember() {
    _pickMembersAndAct(
      title: AppLocalizations.of(context)!.addAllowedMember,
      targetType: GroupMemberType.Allowed,
      action: (ids) => Imclient.allowGroupMember(_groupInfo.target, true, ids, () {}, (code) {}),
    );
  }

  void _pickMembersAndAct({
    required String title,
    required GroupMemberType targetType,
    required void Function(List<String>) action,
  }) {
    final l10n = AppLocalizations.of(context)!;
    List<String> candidates = [];
    List<String> disabledChecked = [];
    for (var member in _members) {
      if (member.type == GroupMemberType.Owner) {
        continue;
      }
      if (member.type == targetType) {
        disabledChecked.add(member.memberId);
      }
      if (member.type == GroupMemberType.Normal ||
          member.type == GroupMemberType.Manager ||
          member.type == GroupMemberType.Muted ||
          member.type == GroupMemberType.Allowed) {
        candidates.add(member.memberId);
      }
    }
    if (candidates.isEmpty) {
      Fluttertoast.showToast(msg: l10n.noCandidateForMute);
      return;
    }
    showPickUserScreen(
      context,
      title: title,
      (pickerContext, pickedUsers) {
        if (pickedUsers.isEmpty) {
          Navigator.pop(pickerContext);
          return;
        }
        action(pickedUsers);
        Navigator.pop(pickerContext);
      },
      candidates: candidates,
      disabledCheckedUsers: disabledChecked,
      showOrganizationEntry: false,
    );
  }

  void _unmuteMember(String memberId) {
    final l10n = AppLocalizations.of(context)!;
    Imclient.muteGroupMember(_groupInfo.target, false, [memberId], () {
      Fluttertoast.showToast(msg: l10n.unmuteSuccess);
    }, (errorCode) {
      Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
    });
  }

  void _unallowMember(String memberId) {
    final l10n = AppLocalizations.of(context)!;
    Imclient.allowGroupMember(_groupInfo.target, false, [memberId], () {
      Fluttertoast.showToast(msg: l10n.unallowSuccess);
    }, (errorCode) {
      Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
    });
  }
}
