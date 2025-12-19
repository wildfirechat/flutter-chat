import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';

class FavGroupsPage extends StatefulWidget {
  const FavGroupsPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FavGroupsPageState();
}

class FavGroupsPageState extends State<FavGroupsPage> {
  List<String> favGroupIds = [];

  @override
  void initState() {
    super.initState();
    Imclient.getFavGroups().then((groupIds) {
      if (groupIds != null) {
        setState(() {
          favGroupIds = groupIds;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏群组'),
      ),
      body: ListView.builder(
        itemCount: favGroupIds.length,
        itemBuilder: (context, index) {
          return _buildGroupItem(favGroupIds[index]);
        },
      ),
    );
  }

  Widget _buildGroupItem(String groupId) {
    return Consumer<GroupViewModel>(
      builder: (context, groupViewModel, child) {
        GroupInfo? groupInfo = groupViewModel.getGroupInfo(groupId);
        if (groupInfo == null) {
          return Container();
        }
        return ListTile(
          leading: Portrait(groupInfo.portrait ?? Config.defaultGroupPortrait, Config.defaultGroupPortrait),
          title: Text(groupInfo.name ?? 'Group'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConversationScreen(
                  Conversation(conversationType: ConversationType.Group, target: groupId, line: 0),
                ),
              ),
            );
          },
        );
      },
    );
  }
}