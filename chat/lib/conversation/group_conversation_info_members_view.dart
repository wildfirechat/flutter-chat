import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/group_view_model.dart';

import 'conversation_info_member_action_item.dart';
import 'conversation_info_member_item.dart';
import 'member_cell_anchor.dart';

class GroupConversationInfoMembersView extends StatelessWidget {
  final Conversation conversation;

  final void Function() onAddActionTap;
  final void Function() onRemoveActionTap;
  final void Function(UserInfo userInfo, Rect anchor) onGroupMemberTap;
  final void Function()? onShowMoreGroupMemberTap;

  const GroupConversationInfoMembersView(this.conversation,
      {required this.onGroupMemberTap, required this.onAddActionTap, required this.onRemoveActionTap, this.onShowMoreGroupMemberTap, super.key});

  @override
  Widget build(BuildContext context) {
    GroupViewModel groupViewModel = Provider.of<GroupViewModel>(context);

    List<UserInfo>? groupMemberUserInfos;
    GroupInfo? groupInfo;
    groupMemberUserInfos = groupViewModel.getGroupMemberUserInfos(conversation.target);
    groupInfo = groupViewModel.getGroupInfo(conversation.target);
    if (groupInfo == null || groupMemberUserInfos == null) {
      return Container();
    }

    List<UserInfo> showGroupMemberUserInfos;

    int columnCount = 5;
    int showLines = 4;
    bool hasMore = false;

    bool showAddAction = false;
    bool showRemoveAction = false;

    late int memberCount;
    showGroupMemberUserInfos = groupMemberUserInfos;
    memberCount = groupMemberUserInfos.length;
    int moreItemCount = 0;
    if (groupInfo.type != GroupType.Organization) {
      if (groupInfo.owner == Imclient.currentUserId) {
        moreItemCount = 2;
        showAddAction = true;
        showRemoveAction = true;
      } else {
        moreItemCount = 1;
        showAddAction = true;
      }
    }

    memberCount += moreItemCount;

    if (memberCount > columnCount * showLines) {
      showGroupMemberUserInfos = groupMemberUserInfos.sublist(0, columnCount * showLines - moreItemCount);
      memberCount = columnCount * showLines;
      hasMore = true;
    }

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
                if (index < showGroupMemberUserInfos.length) {
                  final memberInfo = showGroupMemberUserInfos[index];
                  return Builder(
                    builder: (itemContext) => GestureDetector(
                      onTap: () => onGroupMemberTap(memberInfo, memberCellAnchor(itemContext)),
                      child: ConversationInfoMemberItem(memberInfo),
                    ),
                  );
                } else {
                  if (showRemoveAction && index == memberCount - 1) {
                    return GestureDetector(
                      onTap: () {
                        onRemoveActionTap();
                      },
                      child: const ConversationInfoMemberActionItem(false),
                    );
                  } else if (showAddAction) {
                    return GestureDetector(
                      onTap: () {
                        onAddActionTap();
                      },
                      child: const ConversationInfoMemberActionItem(true),
                    );
                  } else {
                    return Container();
                  }
                }
              },
            ),
            hasMore
                ? Center(
                    child: TextButton(
                      onPressed: () {
                        onShowMoreGroupMemberTap?.call();
                      },
                      child: const Text("查看更多群成员 >"),
                    ),
                  )
                : const Padding(padding: EdgeInsets.only(top: 15)),
          ],
        );
      },
    );
  }
}
