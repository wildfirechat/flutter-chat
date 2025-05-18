import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/conversation_member_action_item.dart';
import 'package:wfc_example/messages/conversation_member_item.dart';
import 'package:wfc_example/viewmodel/group_conversation_info_view_model.dart';

import '../config.dart';

class SingleConversationMemberView extends StatelessWidget {
  final Conversation conversation;
  final UserInfo userInfo;

  final void Function() onAddActionTap;
  final void Function(UserInfo userInfo) onUserTap;

  const SingleConversationMemberView(this.conversation, this.userInfo, {required this.onUserTap, required this.onAddActionTap, super.key});

  @override
  Widget build(BuildContext context) {
    List<UserInfo> userInfos = [userInfo];
    int columnCount = 5;
    int memberCount = 2;

    double screenWidth = MediaQuery.of(context).size.width;

    int lines = (memberCount - 1) ~/ columnCount + 1;
    double gridHeight = (screenWidth / 5) * lines;

    return Column(
      children: [
        SizedBox(
          height: gridHeight,
          child: GridView.builder(
              itemCount: memberCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) {
                if (index < userInfos.length) {
                  return GestureDetector(
                    onTap: () {
                      onUserTap(userInfos[index]);
                    },
                    child: ConversationMemberItem(userInfos[index]),
                  );
                } else {
                  return GestureDetector(
                    onTap: () {
                      onAddActionTap();
                    },
                    child: const ConversationMemberActionItem(true),
                  );
                }
              }),
        ),
        const Padding(padding: EdgeInsets.only(top: 15)),
      ],
    );
  }
}
