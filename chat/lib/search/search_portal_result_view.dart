import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:chat/l10n/app_localizations.dart';

import '../conversation/conversation_screen.dart';
import '../utilities.dart';
import '../viewmodel/channel_view_model.dart';
import '../viewmodel/group_view_model.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/group_list_view/index_path.dart';
import 'search_conversation_result_view.dart';
import '../user_info_widget.dart';
import 'package:chat/theme/app_colors.dart';

// 需要 StatefulWidget 才能保持 SearchVieModel，实现实时搜索
class SearchPortalResultView extends StatefulWidget {
  final String query;

  /// 桌面端 Shell 注入:点击结果时回调(替代默认的全屏 push)。移动端不传,保持原有行为。
  final void Function(String userId)? onUserSelected;
  final void Function(Conversation conversation, {int? focusMessageId})? onConversationSelected;

  final bool shrinkWrap;

  const SearchPortalResultView(
    this.query, {
    super.key,
    this.onUserSelected,
    this.onConversationSelected,
    this.shrinkWrap = false,
  });

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
              ? Container(
                  height: widget.shrinkWrap ? 80.0 : null,
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(context)!.noSearchResult,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                )
              : GroupListView(
                  shrinkWrap: widget.shrinkWrap,
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
                        _buildConversationSearchResultItem(groupedSearchResults.values.toList()[index.section][index.index] as ConversationSearchInfo)
                    };
                  },
                  groupHeaderBuilder: (BuildContext context, int section) {
                    var sectionTitle = switch (groupedSearchResults.keys.toList()[section]) {
                      SearchType.User => AppLocalizations.of(context)!.user,
                      SearchType.Friend => AppLocalizations.of(context)!.contact,
                      SearchType.Conversation => AppLocalizations.of(context)!.chatHistory,
                      SearchType.Group => AppLocalizations.of(context)!.group,
                      SearchType.Channel => AppLocalizations.of(context)!.channel
                    };
                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        sectionTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 0),
                  sectionSeparatorBuilder: (context, section) => section == groupedSearchResults.length - 1
                      ? const SizedBox(height: 0)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: const Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Color(0xFFEEEEEE),
                          ),
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

  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle, TextStyle highlightStyle) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <int>[];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(index);
      start = index + lowerQuery.length;
    }
    if (matches.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    int lastIndex = 0;
    for (final index in matches) {
      if (index > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, index), style: baseStyle));
      }
      spans.add(TextSpan(text: text.substring(index, index + query.length), style: highlightStyle));
      lastIndex = index + query.length;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUserSearchResultItem(UserInfo userInfo) {
    return _SearchItem(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 36, height: 36, borderRadius: 4.0),
      title: _buildHighlightedText(
        userInfo.getReadableName(),
        widget.query,
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
        TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.accent),
      ),
      onTap: () => _openUser(userInfo.userId),
    );
  }

  Widget _buildFriendSearchResultItem(UserInfo userInfo) {
    return _SearchItem(
      leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 36, height: 36, borderRadius: 4.0),
      title: _buildHighlightedText(
        userInfo.getReadableName(),
        widget.query,
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
        TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.accent),
      ),
      onTap: () => _openUser(userInfo.userId),
    );
  }

  Widget _buildGroupSearchResultItem(GroupSearchInfo info) {
    if (info.groupInfo == null) {
      return Container();
    }
    final groupName = info.groupInfo!.name ?? 'Group';
    return _SearchItem(
      leading: Portrait(info.groupInfo!.portrait ?? Config.defaultGroupPortrait, Config.defaultGroupPortrait, width: 36, height: 36, borderRadius: 4.0),
      title: _buildHighlightedText(
        groupName,
        widget.query,
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
        TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.accent),
      ),
      subtitle: (info.marchType & 2 != 0 && info.marchedMemberNames != null && info.marchedMemberNames!.isNotEmpty)
          ? Text(
              "包含成员: ${info.marchedMemberNames!.join(" ")}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            )
          : null,
      onTap: () => _openConversation(Conversation(conversationType: ConversationType.Group, target: info.groupInfo!.target, line: 0)),
    );
  }

  Widget _buildChannelSearchResultItem(ChannelInfo info) {
    return _SearchItem(
      leading: Portrait(info.portrait ?? Config.defaultChannelPortrait, Config.defaultChannelPortrait, width: 36, height: 36, borderRadius: 4.0),
      title: _buildHighlightedText(
        info.name ?? 'Channel',
        widget.query,
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
        TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.accent),
      ),
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
          final titleText = Utilities.conversationTitle(context, conversation, rec.$1, rec.$2, rec.$3);
          
          Widget? subtitleWidget;
          if (info.marchedCount > 1) {
            subtitleWidget = Text(
              AppLocalizations.of(context)!.matchedMessageCount(info.marchedCount.toString()),
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            );
          } else if (info.marchedMessage != null) {
            subtitleWidget = FutureBuilder<String>(
                future: info.marchedMessage!.content.digest(info.marchedMessage!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                    return _buildHighlightedText(
                      snapshot.data!,
                      widget.query,
                      TextStyle(fontSize: 12, color: context.colors.textSecondary),
                      TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.accent),
                    );
                  } else {
                    return Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }
                });
          }

          return _SearchItem(
            leading: _buildConversationPortraitImage(conversation, rec.$1, rec.$2, rec.$3),
            title: _buildHighlightedText(
              titleText,
              widget.query,
              TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
              TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.accent),
            ),
            subtitle: subtitleWidget,
            onTap: () {
              if (info.marchedCount == 1) {
                _openConversation(conversation, focusMessageId: info.marchedMessage?.messageId);
              } else if (info.marchedCount > 1) {
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
    return Portrait(portrait, defaultPortrait, width: 36, height: 36, borderRadius: 4.0);
  }
}

class _SearchItem extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;

  const _SearchItem({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color hoverColor = isDark 
        ? Colors.white10 
        : const Color(0xFFF2F2F2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: hoverColor,
        splashColor: hoverColor.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      subtitle!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
