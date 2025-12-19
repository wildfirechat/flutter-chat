import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/viewmodel/search_view_model.dart';
import 'package:wfc_example/widget/group_list_view/list_view.dart';
import 'package:wfc_example/widget/portrait.dart';

import '../conversation/conversation_screen.dart';
import '../utilities.dart';
import '../viewmodel/channel_view_model.dart';
import '../viewmodel/group_view_model.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/group_list_view/index_path.dart';

// 需要 StatefulWidget 才能保持 SearchVieModel，实现实时搜索
class SearchPortalResultView extends StatefulWidget {
  final String query;

  const SearchPortalResultView(this.query, {super.key});

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
              ? const Center(
                  child: Text(
                    '没有搜索到任何结果',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : GroupListView(
                  padding: const EdgeInsets.all(0),
                  sectionsCount: groupedSearchResults.keys.toList().length,
                  countOfItemInSection: (int section) {
                    return groupedSearchResults.values.toList()[section].length;
                  },
                  itemBuilder: (BuildContext context, IndexPath index) {
                    return switch (groupedSearchResults.keys.toList()[index.section]) {
                      SearchType.User => _buildUserSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as UserInfo),
                      SearchType.Friend => _buildFriendSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as UserInfo),
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
                      SearchType.User => '用户',
                      SearchType.Friend => '联系人',
                      SearchType.Conversation => '聊天记录',
                      // TODO 根据类型显示不同的 cell
                      _ => '其他'
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

  Widget _buildUserSearchResultItem(UserInfo userInfo) {
    return ListTile(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
      title: Text(userInfo.getReadableName()),
      onTap: () {
        Fluttertoast.showToast(msg: 'TODO user click');
      },
    );
  }

  Widget _buildFriendSearchResultItem(UserInfo userInfo) {
    return ListTile(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
      title: Text(userInfo.getReadableName()),
      onTap: () {
        Fluttertoast.showToast(msg: 'TODO friend click');
      },
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
            title: Text(Utilities.conversationTitle(conversation, rec.$1, rec.$2, rec.$3)),
            subtitle: info.marchedCount > 1
                ? Text('${info.marchedCount} 条消息')
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
              if (info.marchedCount == 0 || info.marchedCount == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationScreen(
                      conversation,
                      toFocusMessageId: info.marchedMessage?.messageId,
                    ),
                  ),
                );
              } else {
                Fluttertoast.showToast(msg: 'TODO conversation click');
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
