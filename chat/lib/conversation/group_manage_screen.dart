import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../app_navigator.dart';
import '../group/join_group_request_screen.dart';
import '../pc/pc_platform.dart';
import '../pc/widgets/pc_page_header.dart';
import 'group_manager_screen.dart';
import 'group_mute_screen.dart';

class GroupManageScreen extends StatefulWidget {
  final GroupInfo groupInfo;

  const GroupManageScreen({super.key, required this.groupInfo});

  @override
  State<GroupManageScreen> createState() => _GroupManageScreenState();
}

class _GroupManageScreenState extends State<GroupManageScreen> {
  late GroupInfo _groupInfo;
  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;
  bool? _isCommercialServer;
  GroupMember? _currentMember;

  @override
  void initState() {
    super.initState();
    _groupInfo = widget.groupInfo;
    _loadCommercialServer();
    _loadCurrentMember();
    _groupInfoUpdatedSubscription = Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      for (var info in event.groupInfos) {
        if (info.target == _groupInfo.target) {
          setState(() {
            _groupInfo = info;
          });
          break;
        }
      }
    });
  }

  void _loadCommercialServer() async {
    bool value = await Imclient.isCommercialServer();
    if (mounted) {
      setState(() {
        _isCommercialServer = value;
      });
    }
  }

  void _loadCurrentMember() async {
    var member = await Imclient.getGroupMember(_groupInfo.target, Imclient.currentUserId);
    if (mounted) {
      setState(() {
        _currentMember = member;
      });
    }
  }

  @override
  void dispose() {
    _groupInfoUpdatedSubscription.cancel();
    super.dispose();
  }

  bool get _isOwner => _currentMember?.type == GroupMemberType.Owner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: '群管理',
              onBack: () => Navigator.of(context).maybePop(),
            )
          : AppBar(
              title: Text(l10n.groupManagement),
            ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section 0: 成员管理
            if (_isOwner)
              OptionItem(l10n.managerSetting, onTap: () {
                openPage(context, GroupManagerScreen(groupInfo: _groupInfo));
              }),
            OptionItem(l10n.muteSetting, onTap: () {
              openPage(context, GroupMuteScreen(groupInfo: _groupInfo));
            }),
            OptionSwitchItem(l10n.allowTemporarySession, _groupInfo.privateChat == 0, (value) {
              Imclient.modifyGroupInfo(
                _groupInfo.target,
                ModifyGroupInfoType.Modify_Group_PrivateChat,
                value ? "0" : "1",
                () {
                  setState(() {
                    _groupInfo.privateChat = value ? 0 : 1;
                  });
                },
                (errorCode) {
                  Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
                },
              );
            }),
            const SectionDivider(),
            // Section 1: 群通用设置
            OptionItem(
              l10n.joinGroupPermission,
              desc: _joinTypeDesc(context),
              onTap: _showJoinTypePicker,
            ),
            OptionItem(
              l10n.groupVisible,
              desc: _groupInfo.searchable == 0 ? l10n.searchable : l10n.notSearchable,
              onTap: _showSearchablePicker,
            ),
            if (_isCommercialServer == true) ...[
              OptionSwitchItem(l10n.groupHistoryMessage, _groupInfo.historyMessage == 1, (value) {
                Imclient.modifyGroupInfo(
                  _groupInfo.target,
                  ModifyGroupInfoType.Modify_Group_History_Message,
                  value ? "1" : "0",
                  () {
                    setState(() {
                      _groupInfo.historyMessage = value ? 1 : 0;
                    });
                  },
                  (errorCode) {
                    Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
                  },
                );
              }),
              OptionItem(
                l10n.groupMaxMember,
                desc: _groupInfo.maxMemberCount > 0 ? _groupInfo.maxMemberCount.toString() : '',
                showRightArrow: false,
              ),
            ],
            const SectionDivider(),
            // Section 2: 入群申请
            if (_isOwner && _groupInfo.type == GroupType.Restricted && _groupInfo.joinType == 3)
              OptionItem(l10n.joinGroupRequests, onTap: () {
                openPage(context, JoinGroupRequestScreen(groupId: _groupInfo.target));
              }),
          ],
        ),
      ),
    );
  }

  String _joinTypeDesc(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_groupInfo.joinType) {
      case 0:
        return l10n.freeToJoin;
      case 1:
        return l10n.memberInviteOnly;
      case 2:
        return l10n.managerInviteOnly;
      case 3:
        return l10n.needManagerVerify;
      default:
        return '';
    }
  }

  void _showJoinTypePicker() {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (0, l10n.freeToJoin),
      (1, l10n.memberInviteOnly),
      (2, l10n.managerInviteOnly),
      if (_groupInfo.type == GroupType.Restricted) (3, l10n.needManagerVerify),
    ];
    _showSelectionDialog(l10n.joinGroupPermission, options, _groupInfo.joinType, (selected) {
      if (selected == _groupInfo.joinType) return;
      Imclient.modifyGroupInfo(
        _groupInfo.target,
        ModifyGroupInfoType.Modify_Group_JoinType,
        selected.toString(),
        () {},
        (errorCode) {
          Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
        },
      );
    });
  }

  void _showSearchablePicker() {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (0, l10n.searchable),
      (1, l10n.notSearchable),
    ];
    _showSelectionDialog(l10n.groupVisible, options, _groupInfo.searchable, (selected) {
      if (selected == _groupInfo.searchable) return;
      Imclient.modifyGroupInfo(
        _groupInfo.target,
        ModifyGroupInfoType.Modify_Group_Searchable,
        selected.toString(),
        () {},
        (errorCode) {
          Fluttertoast.showToast(msg: '${l10n.setFail}$errorCode');
        },
      );
    });
  }

  void _showSelectionDialog(
    String title,
    List<(int, String)> options,
    int currentValue,
    ValueChanged<int> onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((option) {
                return ListTile(
                  title: Text(option.$2),
                  trailing: option.$1 == currentValue ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(option.$1);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
