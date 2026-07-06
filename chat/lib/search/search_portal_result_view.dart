import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/widget/group_list_view/list_view.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../conversation/conversation_screen.dart';
import '../utilities.dart';
import '../viewmodel/channel_view_model.dart';
import '../viewmodel/group_view_model.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/group_list_view/index_path.dart';
import 'search_conversation_result_view.dart';
import '../user_info_widget.dart';

// 需要 StatefulWidget 才能保持 SearchVieModel，实现实时搜索
class SearchPortalResultView extends StatefulWidget {
  final String query;

  /// 桌面端 Shell 注入:点击结果时回调(替代默认的全屏 push)。移动端不传,保持原有行为。
  final void Function(String userId)? onUserSelected;
  final void Function(Conversation conversation, {int? focusMessageId})? onConversationSelected;

  const SearchPortalResultView(this.query, {super.key, this.onUserSelected, this.onConversationSelected});

  @override
  State<SearchPortalResultView> createState() => _SearchPortalResultViewState();
}

class _SearchPortalResultViewState extends State<SearchPortalResultView> {
  SearchViewModel? _searchViewModel;

  @override
  Widget build(BuildContext context) {
    _searchViewModel?.search(widget.query);
    return ChangeNotifierProvider<SearchViewModel>(
      create: (_) {
        var vm = SearchViewModel();
        vm.search(widget.query);
        _searchViewModel = vm;
        return vm;
      },
      child: Consumer<SearchViewModel>(
        builder: (context, vm, child) {
          var groupedSearchResults = vm.groupedSearchResult;
          groupedSearchResults.removeWhere((key, value) => value.isEmpty);
          // 排序
          groupedSearchResults = Map.fromEntries(groupedSearchResults.entries.toList()
            ..sort((a, b) {
              // searchType 的自然顺序
              return a.key.index.compareTo(b.key.index);
            }));

          return groupedSearchResults.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noSearchResult,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : GroupListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(0),
                  sectionsCount: groupedSearchResults.keys.toList().length,
                  countOfItemInSection: (int section) {
                    return groupedSearchResults.values.toList()[section].length;
                  },
                  itemBuilder: (BuildContext context, IndexPath index) {
                    return switch (groupedSearchResults.keys.toList()[index.section]) {
                      SearchType.User => _buildUserSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as UserInfo),
                      SearchType.Friend => _buildFriendSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as UserInfo),
                      SearchType.Group => _buildGroupSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as GroupSearchInfo),
                      SearchType.Channel => _buildChannelSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as ChannelInfo),
                      SearchType.Conversation =>
                        _buildConversationSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as ConversationSearchInfo),
                      // TODO 根据类型显示不同的 cell
                      _ => Text(
                          groupedSearchResults.values.toList()[index.section][index.index].toString(),
                          style: const TextStyle(fontSize: 13),
                        )
                    };
                  },
                  groupHeaderBuilder: (BuildContext context, int section) {
                    var sectionTitle = switch (groupedSearchResults.keys.toList()[section]) {
                      SearchType.User => AppLocalizations.of(context)!.user,
                      SearchType.Friend => AppLocalizations.of(context)!.contact,
                      SearchType.Conversation => AppLocalizations.of(context)!.chatHistory,
                      SearchType.Group => AppLocalizations.of(context)!.group,
                      SearchType.Channel => AppLocalizations.of(context)!.channel,
                      // TODO 根据类型显示不同的 cell
                      _ => AppLocalizations.of(context)!.others
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Text(
                        sectionTitle,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => Container(
                      margin: const EdgeInsets.fromLTRB(74.0, 0, 12, 0),
                      child: const Divider(
                        height: 0.5,
                        color: Color(0xffebebeb),
                      )),
                  sectionSeparatorBuilder: (context, section) => section == groupedSearchResults.length - 1
                      ? Container(
                          height: 0,
                        )
                      : Container(
                          height: 10,
                          color: Colors.black12,
                        ),
                );
        },
      ),
    );
  }

  void _openUser(String userId) {
    if (widget.onUserSelected != null) {
      widget.onUserSelected!(userId);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(userId)),
    );
  }

  void _openConversation(Conversation conversation, {int? focusMessageId}) {
    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!(conversation, focusMessageId: focusMessageId);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationScreen(conversation, toFocusMessageId: focusMessageId)),
    );
  }

  Widget _buildUserSearchResultItem(UserInfo userInfo) {
    return ListTile(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
      title: Text(userInfo.getReadableName()),
      onTap: () => _openUser(userInfo.userId),
    );
  }

  Widget _buildFriendSearchResultItem(UserInfo userInfo) {
    return ListTile(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
      title: Text(userInfo.getReadableName()),
      onTap: () => _openUser(userInfo.userId),
    );
  }

  Widget _buildGroupSearchResultItem(GroupSearchInfo info) {
    if (info.groupInfo == null) {
      return Container();
    }
    return ListTile(
      leading: Portrait(info.groupInfo!.portrait ?? Config.defaultGroupPortrait, Config.defaultGroupPortrait),
      title: Text(info.groupInfo!.name ?? 'Group', maxLines: 1,),
      subtitle: (info.marchType & 2 != 0 && info.marchedMemberNames != null && info.marchedMemberNames!.isNotEmpty)
          ? Text("包含成员: ${info.marchedMemberNames!.join(" ")}", maxLines: 1,)
          : null,
      onTap: () => _openConversation(Conversation(conversationType: ConversationType.Group, target: info.groupInfo!.target, line: 0)),
    );
  }

  Widget _buildChannelSearchResultItem(ChannelInfo info) {
    return ListTile(
      leading: Portrait(info.portrait ?? Config.defaultChannelPortrait, Config.defaultChannelPortrait),
      title: Text(info.name ?? 'Channel'),
      onTap: () => _openConversation(Conversation(conversationType: ConversationType.Channel, target: info.channelId, line: 0)),
    );
  }

  Widget _buildConversationSearchResultItem(ConversationSearchInfo info) {
    var conversation = info.conversation;
    return Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo)>(
        selector: (context, userViewModel, groupViewModel, channelViewModel) => (
              conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
              conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
              conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
            ),
        builder: (context, rec, child) {
          return ListTile(
            leading: _buildConversationPortraitImage(conversation, rec.$1, rec.$2, rec.$3),
            title: Text(Utilities.conversationTitle(context, conversation, rec.$1, rec.$2, rec.$3)),
            subtitle: info.marchedCount > 1
                ? Text(AppLocalizations.of(context)!.matchedMessageCount(info.marchedCount.toString()))
                : info.marchedMessage == null
                    ? null
                    : FutureBuilder(
                        future: info.marchedMessage!.content.digest(info.marchedMessage!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return Text(
                              snapshot.data ?? '',
                              maxLines: 1,
                            );
                          } else {
                            return Container(
                              width: 100,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }
                        }),
            onTap: () {
              if (info.marchedCount == 1) {
                _openConversation(conversation, focusMessageId: info.marchedMessage?.messageId);
              } else if (info.marchedCount > 1) {
                // 多条命中:桌面端暂直接打开会话(记录内检索是 M3 项),移动端进入次级检索页
                if (widget.onConversationSelected != null) {
                  widget.onConversationSelected!(conversation);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchConversationResultView(
                      conversation: conversation,
                      keyword: widget.query,
                    ),
                  ),
                );
              }
            },
          );
        });
  }

  Widget _buildConversationPortraitImage(Conversation conversation, UserInfo? userInfo, GroupInfo? groupInfo, ChannelInfo? channelInfo) {
    String portrait = switch (conversation.conversationType) {
      ConversationType.Single => userInfo?.portrait ?? Config.defaultUserPortrait,
      ConversationType.Group => groupInfo?.portrait ?? Config.defaultGroupPortrait,
      ConversationType.Channel => channelInfo?.portrait ?? Config.defaultChannelPortrait,
      _ => ''
    };
    var defaultPortrait = conversation.conversationType == ConversationType.Single
        ? Config.defaultUserPortrait
        : conversation.conversationType == ConversationType.Group
            ? Config.defaultGroupPortrait
            : Config.defaultChannelPortrait;
    return Portrait(portrait, defaultPortrait, borderRadius: 6.0);
  }
}
