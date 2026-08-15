import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/mesh/mesh_cache.dart';

import '../contact/pick_user_screen.dart';
import '../pc/widgets/pc_page_header.dart';
import 'package:chat/app_shell.dart';

class GroupManagerScreen extends StatefulWidget {
  final GroupInfo groupInfo;

  const GroupManagerScreen({super.key, required this.groupInfo});

  @override
  State<GroupManagerScreen> createState() => _GroupManagerScreenState();
}

class _GroupManagerScreenState extends State<GroupManagerScreen> {
  late GroupInfo _groupInfo;
  List<GroupMember> _members = [];
  Map<String, UserInfo> _userInfoMap = {};
  bool _loading = true;
  late StreamSubscription<GroupMembersUpdatedEvent>
      _groupMembersUpdatedSubscription;

  @override
  void initState() {
    super.initState();
    _groupInfo = widget.groupInfo;
    _loadMembers();
    _groupMembersUpdatedSubscription =
        Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
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
      var userInfos =
          await Imclient.getUserInfos(memberIds, groupId: _groupInfo.target);
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

  GroupMember? get _ownerMember {
    for (var member in _members) {
      if (member.type == GroupMemberType.Owner) {
        return member;
      }
    }
    return null;
  }

  List<GroupMember> get _managerMembers {
    return _members.where((m) => m.type == GroupMemberType.Manager).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppShell.isDesktopStyle
          ? PcPageHeader(title: l10n.managerSetting)
          : AppBar(
              title: Text(l10n.managerSetting),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_ownerMember != null)
                  _buildMemberTile(context, _ownerMember!, l10n.groupOwner,
                      showRemove: false),
                ..._managerMembers.map((member) => _buildMemberTile(
                    context, member, l10n.groupManager,
                    showRemove: true)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManager,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMemberTile(
      BuildContext context, GroupMember member, String roleLabel,
      {required bool showRemove}) {
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        UserInfo? userInfo = _userInfoMap[member.memberId];
        return ListTile(
          leading: Portrait(
              userInfo?.portrait ?? '', Config.defaultUserPortrait,
              width: 44, height: 44, borderRadius: 6),
          title:
              userInfo != null ? MeshUserName(userInfo) : Text(member.memberId),
          subtitle: Text(roleLabel),
          trailing: showRemove
              ? TextButton(
                  onPressed: () => _removeManager(member.memberId),
                  child: Text(
                    AppLocalizations.of(context)!.remove,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : null,
        );
      },
    );
  }

  void _addManager() {
    final l10n = AppLocalizations.of(context)!;
    var owner = _ownerMember;
    List<String> candidates = [];
    List<String> disabledChecked = [];
    for (var member in _members) {
      if (owner != null && member.memberId == owner.memberId) {
        continue;
      }
      if (member.type == GroupMemberType.Manager) {
        disabledChecked.add(member.memberId);
      }
      candidates.add(member.memberId);
    }
    if (candidates.isEmpty) {
      Fluttertoast.showToast(msg: l10n.noCandidateForManager);
      return;
    }
    showPickUserScreen(
      context,
      title: l10n.addManager,
      (pickerContext, pickedUsers) {
        if (pickedUsers.isEmpty) {
          Navigator.pop(pickerContext);
          return;
        }
        Imclient.setGroupManager(_groupInfo.target, true, pickedUsers, () {
          Navigator.pop(pickerContext);
        }, (errorCode) {
          Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
        });
      },
      candidates: candidates,
      disabledCheckedUsers: disabledChecked,
      showOrganizationEntry: false,
    );
  }

  void _removeManager(String memberId) {
    final l10n = AppLocalizations.of(context)!;
    Imclient.setGroupManager(_groupInfo.target, false, [memberId], () {
      Fluttertoast.showToast(msg: l10n.removeManagerSuccess);
    }, (errorCode) {
      Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
    });
  }
}
