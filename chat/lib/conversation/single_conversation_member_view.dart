import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_info_member_action_item.dart';
import 'package:chat/conversation/conversation_info_member_item.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double cellWidth = width / 5;
        double cellHeight = 76.0;
        double childAspectRatio = cellWidth / cellHeight;

        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              itemCount: memberCount,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                if (index < userInfos.length) {
                  return GestureDetector(
                    onTap: () {
                      onUserTap(userInfos[index]);
                    },
                    child: ConversationInfoMemberItem(userInfos[index]),
                  );
                } else {
                  return GestureDetector(
                    onTap: () {
                      onAddActionTap();
                    },
                    child: const ConversationInfoMemberActionItem(true),
                  );
                }
              },
            ),
            const Padding(padding: EdgeInsets.only(top: 15)),
          ],
        );
      },
    );
  }
}
