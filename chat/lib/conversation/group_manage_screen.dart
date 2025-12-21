import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:chat/widget/option_switch_item.dart';

class GroupManageScreen extends StatefulWidget {
  final GroupInfo groupInfo;

  const GroupManageScreen({super.key, required this.groupInfo});

  @override
  State<GroupManageScreen> createState() => _GroupManageScreenState();
}

class _GroupManageScreenState extends State<GroupManageScreen> {
  late GroupInfo _groupInfo;

  @override
  void initState() {
    super.initState();
    _groupInfo = widget.groupInfo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群管理'),
      ),
      body: Column(
        children: [
          OptionSwitchItem('全员禁言', _groupInfo.mute == 1, (value) {
            Imclient.modifyGroupInfo(_groupInfo.target, ModifyGroupInfoType.Modify_Group_Mute, value ? "1" : "0", () {
              setState(() {
                _groupInfo.mute = value ? 1 : 0;
              });
            }, (errorCode) {
              // Handle error
            });
          }),
          OptionSwitchItem('私聊', _groupInfo.privateChat == 0, (value) {
             Imclient.modifyGroupInfo(_groupInfo.target, ModifyGroupInfoType.Modify_Group_PrivateChat, value ? "0" : "1", () {
              setState(() {
                _groupInfo.privateChat = value ? 0 : 1;
              });
            }, (errorCode) {
              // Handle error
            });
          }),
          // Add more management options here like Transfer Owner, Set Manager, etc.
        ],
      ),
    );
  }
}
