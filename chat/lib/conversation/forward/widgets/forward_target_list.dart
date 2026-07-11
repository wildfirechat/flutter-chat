import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/forward/forward_target_controller.dart';
import 'package:chat/conversation/forward/widgets/conversation_display.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_typography.dart';

/// 转发目标列表:搜索为空时显示“创建群聊”入口 + 最近聊天,否则显示搜索结果。
/// 移动端整页、桌面端左栏共用这一份。
class ForwardTargetList extends StatelessWidget {
  /// 调用方搜索时必须传这个,否则会搜出本列表不消费的类型。
  ///
  /// 不搜 [SearchType.User]:那是服务端全网用户搜索,会把陌生人混进转发目标,
  /// 且好友本身也在用户表里,同一个人会在“好友”之外再出现一次。
  static const List<SearchType> searchTypes = [SearchType.Friend, SearchType.Group];

  final ForwardTargetController controller;
  final SearchViewModel searchViewModel;
  final String searchText;
  final ValueChanged<Conversation> onTargetTap;
  final VoidCallback onCreateGroupTap;

  const ForwardTargetList({
    super.key,
    required this.controller,
    required this.searchViewModel,
    required this.searchText,
    required this.onTargetTap,
    required this.onCreateGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => searchText.isEmpty
          ? _buildRecentConversations(context)
          : ListenableBuilder(
              listenable: searchViewModel,
              builder: (context, child) => _buildSearchResults(context),
            ),
    );
  }

  Widget _buildRecentConversations(BuildContext context) {
    final conversationList = context.watch<ConversationListViewModel>().conversationList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateGroupEntry(onTap: onCreateGroupTap),
        _SectionHeader(AppLocalizations.of(context)!.recentChats),
        Expanded(
          child: ListView.builder(
            itemCount: conversationList.length,
            itemExtent: LayoutScale.watchScale(context, 64.0, cap: LayoutScale.rowCap),
            itemBuilder: (context, i) {
              ConversationInfo info = conversationList[i];
              return _buildLiveTile(info.conversation, showCheckbox: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> results = [];

    if (searchViewModel.searchedFriends.isNotEmpty) {
      results.add(_SectionHeader(l10n.friends));
      results.addAll(searchViewModel.searchedFriends.map(_buildUserTile));
    }
    if (searchViewModel.searchedGroupInfos.isNotEmpty) {
      results.add(_SectionHeader(l10n.group));
      results.addAll(List<GroupSearchInfo>.from(searchViewModel.searchedGroupInfos).map(_buildGroupTile));
    }

    if (results.isEmpty) {
      return Center(child: Text(l10n.noSearchResult, style: TextStyle(color: context.colors.textSecondary)));
    }
    return ListView(children: results);
  }

  /// 最近聊天:标题/头像随 ViewModel 异步刷新。
  Widget _buildLiveTile(Conversation conversation, {required bool showCheckbox}) {
    return ConversationDisplay(
      conversation: conversation,
      builder: (context, info) => _ConversationTile(
        title: info.title,
        portrait: info.portrait,
        defaultPortrait: info.defaultPortrait,
        selected: controller.isSelected(conversation),
        showCheckbox: controller.isMultiSelect && showCheckbox,
        onTap: () => onTargetTap(conversation),
      ),
    );
  }

  /// 搜索结果:标题/头像已随结果返回,不必再订阅 ViewModel,也不显示勾选框。
  Widget _buildUserTile(UserInfo user) {
    final conversation = Conversation(conversationType: ConversationType.Single, target: user.userId, line: 0);
    return _ConversationTile(
      title: MeshUserDisplay.getReadableName(user),
      portrait: user.portrait ?? Config.defaultUserPortrait,
      defaultPortrait: Config.defaultUserPortrait,
      selected: controller.isSelected(conversation),
      showCheckbox: false,
      onTap: () => onTargetTap(conversation),
    );
  }

  Widget _buildGroupTile(GroupSearchInfo groupSearchInfo) {
    final groupInfo = groupSearchInfo.groupInfo;
    if (groupInfo == null) return const SizedBox.shrink();
    final conversation = Conversation(conversationType: ConversationType.Group, target: groupInfo.target, line: 0);
    return _ConversationTile(
      title: groupInfo.name ?? 'Group',
      portrait: groupInfo.portrait ?? Config.defaultGroupPortrait,
      defaultPortrait: Config.defaultGroupPortrait,
      selected: controller.isSelected(conversation),
      showCheckbox: false,
      onTap: () => onTargetTap(conversation),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String portrait;
  final String defaultPortrait;
  final bool selected;
  final bool showCheckbox;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.title,
    required this.portrait,
    required this.defaultPortrait,
    required this.selected,
    required this.showCheckbox,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double rowHeight = LayoutScale.watchScale(context, 64.0, cap: LayoutScale.rowCap);
    final double iconSize = LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: context.colors.hoverOverlay,
        child: Container(
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Portrait(portrait, defaultPortrait, borderRadius: 4.0),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.lg.copyWith(color: context.colors.textPrimary),
                ),
              ),
              if (showCheckbox) ...[
                const SizedBox(width: 12.0),
                selected
                    ? Icon(
                        Icons.check_circle,
                        color: context.colors.accent,
                        size: iconSize,
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        color: context.colors.textSecondary,
                        size: iconSize,
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colors.sectionGap,
      child: Text(title, style: AppText.xs.copyWith(color: context.colors.textSecondary)),
    );
  }
}

class _CreateGroupEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateGroupEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double iconBoxSize = LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap);
    final double iconSize = LayoutScale.watchScale(context, 22.0, cap: LayoutScale.iconCap);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: context.colors.hoverOverlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: context.colors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.group_add_rounded, color: Colors.white, size: iconSize),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.createGroupChat,
                style: AppText.lg.copyWith(color: context.colors.textPrimary, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
