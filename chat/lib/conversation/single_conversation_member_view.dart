import 'package:flutter/material.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_info_member_action_item.dart';
import 'package:chat/conversation/conversation_info_member_item.dart';
import 'package:chat/conversation/member_cell_anchor.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';

import '../config.dart';
import 'package:chat/app_shell.dart';

class SingleConversationMemberView extends StatelessWidget {
  final Conversation conversation;
  final UserInfo userInfo;

  final void Function() onAddActionTap;
  final void Function(UserInfo userInfo, Rect anchor) onUserTap;

  const SingleConversationMemberView(this.conversation, this.userInfo,
      {required this.onUserTap, required this.onAddActionTap, super.key});

  @override
  Widget build(BuildContext context) {
    List<UserInfo> userInfos = [userInfo];
    int columnCount = AppShell.isDesktopStyle ? 4 : 5;
    int memberCount = 2;
    // 头像(iconCap)+ 名字(完整跟随字号),格子高度按行高上限放大才装得下。
    // 在 LayoutBuilder 外取值:builder 在 layout 阶段执行,不适合注册 Provider 依赖。
    final double cellHeight =
        LayoutScale.watchScale(context, 80.0, cap: LayoutScale.rowCap);

    return LayoutBuilder(
      builder: (context, constraints) {
        double horizontalPadding = 16.0;
        double crossAxisSpacing = 8.0;
        double mainAxisSpacing = 12.0;
        double width = constraints.maxWidth - horizontalPadding * 2;
        double cellWidth =
            (width - (columnCount - 1) * crossAxisSpacing) / columnCount;
        double childAspectRatio = cellWidth / cellHeight;

        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 12.0),
              itemCount: memberCount,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
              ),
              itemBuilder: (context, index) {
                if (index < userInfos.length) {
                  final memberInfo = userInfos[index];
                  return Builder(
                    builder: (itemContext) => GestureDetector(
                      onTap: () =>
                          onUserTap(memberInfo, memberCellAnchor(itemContext)),
                      child: ConversationInfoMemberItem(memberInfo),
                    ),
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
