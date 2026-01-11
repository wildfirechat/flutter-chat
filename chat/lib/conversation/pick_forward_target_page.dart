import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/utilities.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/home/conversation_list_widget.dart';
import 'forward_confirmation_sheet.dart';

class PickForwardTargetPage extends StatefulWidget {
  final Function(List<Conversation>) onSelected;
  final List<Message>? messages;
  final bool oneByOne;

  const PickForwardTargetPage({super.key, required this.onSelected, this.messages, this.oneByOne = false});

  @override
  State<PickForwardTargetPage> createState() => _PickForwardTargetPageState();
}

class _PickForwardTargetPageState extends State<PickForwardTargetPage> {
  bool _isMultiSelect = false;
  final List<Conversation> _selectedConversations = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchText = '';
  SearchViewModel? _searchViewModel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
      if (_searchText.isNotEmpty) {
        _searchViewModel?.search(_searchText);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSelection(Conversation conversation) {
    setState(() {
      if (_isSelected(conversation)) {
        _selectedConversations.removeWhere((c) => c.target == conversation.target && c.conversationType == conversation.conversationType && c.line == conversation.line);
      } else {
        _selectedConversations.add(conversation);
      }
    });
  }

  bool _isSelected(Conversation conversation) {
    return _selectedConversations.any((c) => c.target == conversation.target && c.conversationType == conversation.conversationType && c.line == conversation.line);
  }

  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelect = !_isMultiSelect;
      if (!_isMultiSelect) {
        _selectedConversations.clear();
      }
    });
  }

  void _onTargetTap(Conversation conversation) {
    if (_isMultiSelect) {
      _toggleSelection(conversation);
      if (_searchText.isNotEmpty) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    } else {
      _showConfirmationDialog([conversation]);
    }
  }

  void _showConfirmationDialog(List<Conversation> targets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ForwardConfirmationSheet(
          targets: targets,
          messages: widget.messages,
          oneByOne: widget.oneByOne,
          onConfirm: (comment) {
            widget.onSelected(targets);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text( _isMultiSelect ? '选择多个聊天' : '选择一个聊天'),
        // default leading back button
        actions: [
           TextButton(
            onPressed: _toggleMultiSelect,
            child: Text(
              _isMultiSelect ? '单选' : '多选',
              style: const TextStyle(color: Colors.blue, fontSize: 16)
            ),
          ),
        ],
      ),
      body: ChangeNotifierProvider<SearchViewModel>(
        create: (_) => SearchViewModel(),
        child: Consumer<SearchViewModel>(
          builder: (context, searchVM, child) {
            _searchViewModel = searchVM;
            return Column(
              children: [
                _buildSearchBar(context),
                Expanded(
                  child: _searchText.isEmpty
                      ? _buildRecentConversations(context)
                      : _buildSearchResults(context, searchVM),
                ),
                if (_isMultiSelect) _buildBottomBar(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
        ),
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                   if (_isMultiSelect && _selectedConversations.isNotEmpty)
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _selectedConversations.map((c) => _buildSelectedChip(c)).toList(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: '搜索',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChip(Conversation conversation) {
    return GestureDetector(
      onTap: () => _toggleSelection(conversation),
      child: Container(
        padding: const EdgeInsets.only(right: 4),
        child: Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo)>(
          selector: (context, userViewModel, groupViewModel, channelViewModel) => (
            conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
            conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
            conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
          ),
          builder: (context, rec, child) {
             String portrait = switch (conversation.conversationType) {
              ConversationType.Single => rec.$1?.portrait ?? Config.defaultUserPortrait,
              ConversationType.Group => rec.$2?.portrait ?? Config.defaultGroupPortrait,
              ConversationType.Channel => rec.$3?.portrait ?? Config.defaultChannelPortrait,
              _ => ''
            };
            var defaultPortrait = conversation.conversationType == ConversationType.Single
                ? Config.defaultUserPortrait
                : conversation.conversationType == ConversationType.Group
                    ? Config.defaultGroupPortrait
                    : Config.defaultChannelPortrait;
            return Portrait(portrait, defaultPortrait, width: 30, height: 30, borderRadius: 4.0);
          },
        ),
      ),
    );
  }

  Widget _buildRecentConversations(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('最近聊天'),
        Expanded(
          child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemExtent: 64.5,
            itemBuilder: (context, i) {
              ConversationInfo info = conversationListViewModel.conversationList[i];
              return _buildConversationItem(info.conversation, info, showCheckbox: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchViewModel vm) {
    // Convert results to a list of Widgets
    List<Widget> resultWidgets = [];

    // Users
    if (vm.searchedUsers.isNotEmpty) {
      resultWidgets.add(_buildSectionHeader('联系人'));
      resultWidgets.addAll(vm.searchedUsers.map((u) => _buildUserItem(u)).toList());
    }

    // Friends
    if (vm.searchedFriends.isNotEmpty) {
      resultWidgets.add(_buildSectionHeader('好友'));
      resultWidgets.addAll(vm.searchedFriends.map((u) => _buildUserItem(u)).toList());
    }

    // Groups
    if (vm.searchedGroupInfos.isNotEmpty) {
      resultWidgets.add(_buildSectionHeader('群组'));
      List<GroupSearchInfo> groups = List<GroupSearchInfo>.from(vm.searchedGroupInfos);
      resultWidgets.addAll(groups.map((g) => _buildGroupItem(g)).toList());
    }

    if (resultWidgets.isEmpty) {
      return const Center(child: Text('没有搜索到结果', style: TextStyle(color: Colors.grey)));
    }

    return ListView(
      children: resultWidgets,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF5F5F5),
      child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }

  Widget _buildUserItem(UserInfo user) {
    Conversation conv = Conversation(conversationType: ConversationType.Single, target: user.userId, line: 0);
    return _buildConversationItem(conv, null, title: user.getReadableName(), portrait: user.portrait ?? Config.defaultUserPortrait, defaultPortrait: Config.defaultUserPortrait, showCheckbox: false);
  }

  Widget _buildGroupItem(GroupSearchInfo groupInfo) {
    if(groupInfo.groupInfo == null) return Container();
    Conversation conv = Conversation(conversationType: ConversationType.Group, target: groupInfo.groupInfo!.target, line: 0);
    return _buildConversationItem(conv, null, title: groupInfo.groupInfo!.name ?? 'Group', portrait: groupInfo.groupInfo!.portrait ?? Config.defaultGroupPortrait, defaultPortrait: Config.defaultGroupPortrait, showCheckbox: false);
  }

  Widget _buildConversationItem(Conversation conversation, ConversationInfo? info, {String? title, String? portrait, String? defaultPortrait, bool showCheckbox = true}) {
    bool selected = _isSelected(conversation);

    Widget content;
    if (info != null) {
       content = Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo)>(
          selector: (context, userViewModel, groupViewModel, channelViewModel) => (
            conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
            conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
            conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
          ),
          builder: (context, rec, child) {
            return ListTile(
              leading: Portrait(
                switch (conversation.conversationType) {
                  ConversationType.Single => rec.$1?.portrait ?? Config.defaultUserPortrait,
                  ConversationType.Group => rec.$2?.portrait ?? Config.defaultGroupPortrait,
                  ConversationType.Channel => rec.$3?.portrait ?? Config.defaultChannelPortrait,
                  _ => ''
                },
                conversation.conversationType == ConversationType.Single
                  ? Config.defaultUserPortrait
                  : conversation.conversationType == ConversationType.Group
                      ? Config.defaultGroupPortrait
                      : Config.defaultChannelPortrait,
                borderRadius: 4.0
              ),
              title: Text(Utilities.conversationTitle(conversation, rec.$1, rec.$2, rec.$3)),
              trailing: (_isMultiSelect && showCheckbox)
                  ? (selected
                      ? const Icon(Icons.check_circle, color: Color(0xFF3B62E0))
                      : const Icon(Icons.radio_button_unchecked, color: Colors.grey))
                  : null,
            );
          }
       );
    } else {
      content = ListTile(
        leading: Portrait(portrait ?? '', defaultPortrait ?? Config.defaultUserPortrait, borderRadius: 4.0),
        title: Text(title ?? ''),
        trailing: (_isMultiSelect && showCheckbox)
            ? (selected
                ? const Icon(Icons.check_circle, color: Color(0xFF3B62E0))
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey))
            : null,
      );
    }

    return GestureDetector(
      onTap: () => _onTargetTap(conversation),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
        ),
        child: Row(
          children: [
            Text('已选择${_selectedConversations.length}个聊天'),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedConversations.isNotEmpty
                  ? () => _showConfirmationDialog(_selectedConversations)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B62E0),
                disabledBackgroundColor: const Color(0xFFA8BDFF),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text('发送(${_selectedConversations.length})'),
            ),
          ],
        ),
      ),
    );
  }
}
