import 'package:flutter/material.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/theme/app_colors.dart';

import 'conversation_info_member_action_item.dart';
import 'conversation_info_member_item.dart';
import 'member_cell_anchor.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_shell.dart';

class GroupConversationInfoMembersView extends StatefulWidget {
  final Conversation conversation;

  final void Function() onAddActionTap;
  final void Function() onRemoveActionTap;
  final void Function(UserInfo userInfo, Rect anchor) onGroupMemberTap;
  final void Function()? onShowMoreGroupMemberTap;

  const GroupConversationInfoMembersView(this.conversation,
      {required this.onGroupMemberTap,
      required this.onAddActionTap,
      required this.onRemoveActionTap,
      this.onShowMoreGroupMemberTap,
      super.key});

  @override
  State<GroupConversationInfoMembersView> createState() =>
      _GroupConversationInfoMembersViewState();
}

class _GroupConversationInfoMembersViewState
    extends State<GroupConversationInfoMembersView> {
  bool _isExpanded = false;

  // 展开状态下成员数超过该阈值时,GridView 改为固定高度内部滚动,
  // 避免 shrinkWrap 一次性构建全部成员格子
  static const int _expandedScrollThreshold = 50;
  static const int _expandedScrollLines = 6;

  @override
  Widget build(BuildContext context) {
    GroupViewModel groupViewModel = Provider.of<GroupViewModel>(context);

    List<UserInfo>? groupMemberUserInfos;
    GroupInfo? groupInfo;
    groupMemberUserInfos =
        groupViewModel.getGroupMemberUserInfos(widget.conversation.target);
    groupInfo = groupViewModel.getGroupInfo(widget.conversation.target);
    if (groupInfo == null || groupMemberUserInfos == null) {
      return Container();
    }

    List<UserInfo> showGroupMemberUserInfos;

    int columnCount = AppShell.isDesktopStyle ? 4 : 5;
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
      hasMore = true;
      if (!_isExpanded) {
        showGroupMemberUserInfos = groupMemberUserInfos.sublist(
            0, columnCount * showLines - moreItemCount);
        memberCount = columnCount * showLines;
      }
    }

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
        bool scrollableExpanded =
            _isExpanded && memberCount > _expandedScrollThreshold;

        Widget gridView = GridView.builder(
          shrinkWrap: !scrollableExpanded,
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 12.0),
          itemCount: memberCount,
          physics: scrollableExpanded
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemBuilder: (context, index) {
            if (index < showGroupMemberUserInfos.length) {
              final memberInfo = showGroupMemberUserInfos[index];
              return Builder(
                builder: (itemContext) => GestureDetector(
                  onTap: () => widget.onGroupMemberTap(
                      memberInfo, memberCellAnchor(itemContext)),
                  child: ConversationInfoMemberItem(memberInfo),
                ),
              );
            } else {
              if (showRemoveAction && index == memberCount - 1) {
                return GestureDetector(
                  onTap: () {
                    widget.onRemoveActionTap();
                  },
                  child: const ConversationInfoMemberActionItem(false),
                );
              } else if (showAddAction) {
                return GestureDetector(
                  onTap: () {
                    widget.onAddActionTap();
                  },
                  child: const ConversationInfoMemberActionItem(true),
                );
              } else {
                return Container();
              }
            }
          },
        );

        return Column(
          children: [
            scrollableExpanded
                ? SizedBox(
                    // 高度固定为若干行,成员格子在内部按需构建并滚动
                    height: _expandedScrollLines * cellHeight +
                        (_expandedScrollLines - 1) * mainAxisSpacing +
                        24.0,
                    child: gridView,
                  )
                : gridView,
            hasMore
                ? Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                        widget.onShowMoreGroupMemberTap?.call();
                      },
                      child: Text(
                        _isExpanded
                            ? AppLocalizations.of(context)!.collapseGroupMembers
                            : AppLocalizations.of(context)!
                                .viewMoreGroupMembers,
                        style: AppText.base.copyWith(
                            color: context.colors.accent,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                : const Padding(padding: EdgeInsets.only(top: 15)),
          ],
        );
      },
    );
  }
}
