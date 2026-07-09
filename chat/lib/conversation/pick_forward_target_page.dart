import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'forward_confirmation_sheet.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';

class PickForwardTargetPage extends StatefulWidget {
  final Function(List<Conversation> targets, String? comment) onSelected;
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
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchText = '';
  SearchViewModel? _searchViewModel;

  bool _isSelectingMembers = false;
  PickUserViewModel? _pickUserViewModelForGroup;
  final ScrollController _pickUserScrollController = ScrollController();
  final ScrollController _selectedUsersScrollController = ScrollController();
  final TextEditingController _pickUserSearchController = TextEditingController();
  String _currentLetter = '';
  bool _isTouchingIndex = false;

  @override
  void initState() {
    super.initState();
    if (isDesktopShell) {
      _isMultiSelect = true;
    }
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
      if (_searchText.isNotEmpty) {
        _searchViewModel?.search(_searchText);
      }
    });
    _pickUserSearchController.addListener(() {
      _pickUserViewModelForGroup?.search(_pickUserSearchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _commentController.dispose();
    _searchFocusNode.dispose();
    _pickUserScrollController.dispose();
    _selectedUsersScrollController.dispose();
    _pickUserSearchController.dispose();
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
            widget.onSelected(targets, comment);
          },
        );
      },
    );
  }

  Widget _buildSelectedTargetGridItem(Conversation conversation) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          String title = Utilities.conversationTitle(context, conversation, rec.$1, rec.$2, rec.$3);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Portrait(portrait, defaultPortrait, width: 42, height: 42, borderRadius: 4.0),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _toggleSelection(conversation),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.close, size: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF333333), decoration: TextDecoration.none),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessagePreview() {
    if (widget.messages == null || widget.messages!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.messages!.length == 1) {
      final message = widget.messages!.first;
      Widget? mediaWidget;

      if (message.content is ImageMessageContent) {
        final imgContent = message.content as ImageMessageContent;
        if (imgContent.localPath != null && File(imgContent.localPath!).existsSync()) {
          mediaWidget = Container(
            margin: const EdgeInsets.only(top: 6),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: FileImage(File(imgContent.localPath!)),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else if (imgContent.remoteUrl != null) {
          mediaWidget = Container(
            margin: const EdgeInsets.only(top: 6),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: CachedNetworkImageProvider(MediaUrlRedirector.redirect(imgContent.remoteUrl!)),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      }

      return FutureBuilder<String>(
        future: message.content.digest(message),
        builder: (context, snapshot) {
          final text = snapshot.data ?? '加载中...';
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4, decoration: TextDecoration.none),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (mediaWidget != null) mediaWidget,
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E2E2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_rounded, color: Colors.grey, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.oneByOne ? '逐条转发' : '合并转发',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${widget.messages!.length} 条消息',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final titleStr = widget.oneByOne ? '分别发送给' : '合并发送给';
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left column: selection list
          Container(
            width: 280,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFEBEBEB), width: 0.5)),
            ),
            child: Column(
              children: [
                _buildSearchBar(context),
                Expanded(
                  child: _searchText.isEmpty
                      ? _buildRecentConversations(context)
                      : Consumer<SearchViewModel>(
                          builder: (context, searchVM, child) {
                            _searchViewModel = searchVM;
                            return _buildSearchResults(context, searchVM);
                          },
                        ),
                ),
              ],
            ),
          ),
          // Right column: selected targets, preview, comment, actions
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          titleStr,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333), decoration: TextDecoration.none),
                        ),
                        Text(
                          '已选择${_selectedConversations.length}个聊天',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFF0F0F0), height: 1),
                  Expanded(
                    flex: 3,
                    child: _selectedConversations.isEmpty
                        ? const Center(
                            child: Text(
                              '请在左侧选择联系人或群聊',
                              style: TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.none),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedConversations.map((c) => _buildSelectedTargetGridItem(c)).toList(),
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessagePreview(),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _commentController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: '给朋友留言',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFEBEBEB), width: 0.5),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFEBEBEB), width: 0.5),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF3B62E0), width: 1.0),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF0F0F0), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDCDCDC), width: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(color: Color(0xFF333333), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _selectedConversations.isNotEmpty
                              ? () {
                                  widget.onSelected(_selectedConversations, _commentController.text.isEmpty ? null : _commentController.text);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B62E0),
                            disabledBackgroundColor: const Color(0xFFA8BDFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: const Text(
                            '发送',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelectingMembers) {
      return _buildMemberSelectionLayout(context);
    }
    return ChangeNotifierProvider<SearchViewModel>(
      create: (_) => SearchViewModel(),
      child: isDesktopShell
          ? _buildDesktopLayout(context)
          : Scaffold(
              appBar: AppBar(
                title: Text( _isMultiSelect ? AppLocalizations.of(context)!.pickMultipleChats : AppLocalizations.of(context)!.pickOneChat),
                // default leading back button
                actions: [
                   TextButton(
                    onPressed: _toggleMultiSelect,
                    child: Text(
                      _isMultiSelect ? AppLocalizations.of(context)!.singleSelect : AppLocalizations.of(context)!.multiSelect,
                      style: const TextStyle(color: Colors.blue, fontSize: 16)
                    ),
                  ),
                ],
              ),
              body: Consumer<SearchViewModel>(
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
                   if (_isMultiSelect && _selectedConversations.isNotEmpty && !isDesktopShell)
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
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.search,
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

  Widget _buildCreateGroupEntry(BuildContext context) {
    return InkWell(
      onTap: _createGroupChat,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3B62E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.createGroupChat,
              style: const TextStyle(fontSize: 15, color: Color(0xFF333333), decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  void _createGroupChat() {
    setState(() {
      _isSelectingMembers = true;
    });
    _initMemberPicker();
  }

  void _initMemberPicker() async {
    _pickUserViewModelForGroup = PickUserViewModel();
    var userInfos = await UserRepo.getFriendUserInfos();
    _pickUserViewModelForGroup!.setup(userInfos, maxPickCount: 1024);
    if (mounted) {
      setState(() {});
    }
  }

  void _cancelMemberSelection() {
    _pickUserSearchController.clear();
    _pickUserViewModelForGroup = null;
    setState(() {
      _isSelectingMembers = false;
    });
  }

  void _confirmMemberSelection(List<UserInfo> pickedUsers) async {
    final l10n = AppLocalizations.of(context)!;
    final members = pickedUsers.map((u) => u.userId).toList();

    // 只选中一位好友时直接转发到单聊,无需建群
    if (members.length == 1) {
      _cancelMemberSelection();
      _onTargetTap(Conversation(conversationType: ConversationType.Single, target: members[0], line: 0));
      return;
    }

    // 多位好友:创建群聊后再转发,群名参考发起聊天的拼接规则
    List<UserInfo> userInfos = await Imclient.getUserInfos(members);
    UserInfo? creator = await Imclient.getUserInfo(Imclient.currentUserId);
    String groupName = creator?.displayName ?? '';
    for (var user in userInfos) {
      if (user.displayName != null) {
        if ('$groupName,${user.displayName}'.length > 24) {
          groupName = l10n.groupNameEtc(groupName);
          break;
        } else {
          groupName = '$groupName,${user.displayName}';
        }
      }
    }

    Imclient.createGroup(null, groupName, null, GroupType.Restricted.index, members, (groupId) {
      if (!mounted) return;
      _cancelMemberSelection();
      _onTargetTap(Conversation(conversationType: ConversationType.Group, target: groupId, line: 0));
    }, (errorCode) {
      showToast(msg: l10n.createGroupFail('$errorCode'));
    });
  }

  List<String> _getIndexList(List<UIPickUserInfo> userList) {
    List<String> indexList = [];
    indexList.add('↑');
    for (var user in userList) {
      if (user.showCategory) {
        String category = user.category;
        if (category.startsWith("AI")) continue;
        if (category == "{") category = "#";
        if (!indexList.contains(category)) {
          indexList.add(category);
        }
      }
    }
    return indexList;
  }

  void _jumpToTag(String tag, List<UIPickUserInfo> userList) {
    if (tag == '↑') {
      _pickUserScrollController.jumpTo(0.0);
      return;
    }
    String targetCategory = tag;
    if (tag == '#') targetCategory = '{';

    double offset = 0;
    for (var user in userList) {
      if (user.category == targetCategory) {
        _pickUserScrollController.jumpTo(offset);
        return;
      }
      offset += user.showCategory ? 70.5 : 52.5;
    }
  }

  Widget _buildMemberSelectionLayout(BuildContext context) {
    if (_pickUserViewModelForGroup == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelMemberSelection,
          ),
          title: Text(AppLocalizations.of(context)!.startChat),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: _pickUserViewModelForGroup!,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) {
          final l10n = AppLocalizations.of(context)!;
          List<String> indexList = viewModel.isSearching ? [] : _getIndexList(viewModel.userList);
          
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _cancelMemberSelection,
              ),
              title: Text(l10n.startChat),
              actions: [
                TextButton(
                  onPressed: viewModel.pickedUsers.isNotEmpty
                      ? () => _confirmMemberSelection(viewModel.pickedUsers)
                      : null,
                  child: Text(
                    viewModel.pickedUsers.isNotEmpty
                        ? '${l10n.confirm}(${viewModel.pickedUsers.length})'
                        : l10n.confirm,
                    style: TextStyle(
                      color: viewModel.pickedUsers.isNotEmpty ? Colors.blue : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xfff3f4f5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                if (viewModel.pickedUsers.isNotEmpty)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                                    child: SingleChildScrollView(
                                      controller: _selectedUsersScrollController,
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: viewModel.pickedUsers
                                            .map((u) => Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: GestureDetector(
                                                    onTap: () => viewModel.pickUser(u, false),
                                                    child: Portrait(u.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait,
                                                        width: 30, height: 30, borderRadius: 4),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: TextField(
                                    controller: _pickUserSearchController,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: l10n.search,
                                      isDense: true,
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
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          controller: _pickUserScrollController,
                          itemCount: viewModel.userList.length,
                          itemBuilder: (context, i) {
                            var userInfo = viewModel.userList[i];
                            return SelectableUserItem(
                              userInfo,
                              1024,
                              null,
                              onUserPicked: () {
                                if (_pickUserSearchController.text.isNotEmpty) {
                                  _pickUserSearchController.clear();
                                  viewModel.search('');
                                }
                              },
                            );
                          },
                        ),
                        if (indexList.isNotEmpty)
                          SidebarIndex(
                            indexList: indexList,
                            onIndexSelected: (tag) {
                              _jumpToTag(tag, viewModel.userList);
                            },
                            onTouch: (tag, isTouching) {
                              setState(() {
                                _currentLetter = tag;
                                _isTouchingIndex = isTouching;
                              });
                            },
                          ),
                        if (_isTouchingIndex)
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: _currentLetter == '↑'
                                  ? const Icon(Icons.arrow_upward, size: 40, color: Colors.white)
                                  : Text(
                                      _currentLetter,
                                      style: const TextStyle(color: Colors.white, fontSize: 40),
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
        },
      ),
    );
  }

  Widget _buildRecentConversations(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCreateGroupEntry(context),
        _buildSectionHeader( AppLocalizations.of(context)!.recentChats),
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
      resultWidgets.add(_buildSectionHeader(AppLocalizations.of(context)!.contacts));
      resultWidgets.addAll(vm.searchedUsers.map((u) => _buildUserItem(u)).toList());
    }

    // Friends
    if (vm.searchedFriends.isNotEmpty) {
      resultWidgets.add(_buildSectionHeader( AppLocalizations.of(context)!.friends));
      resultWidgets.addAll(vm.searchedFriends.map((u) => _buildUserItem(u)).toList());
    }

    // Groups
    if (vm.searchedGroupInfos.isNotEmpty) {
      resultWidgets.add(_buildSectionHeader( AppLocalizations.of(context)!.group));
      List<GroupSearchInfo> groups = List<GroupSearchInfo>.from(vm.searchedGroupInfos);
      resultWidgets.addAll(groups.map((g) => _buildGroupItem(g)).toList());
    }

    if (resultWidgets.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noSearchResult, style: TextStyle(color: Colors.grey)));
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
              title: Text(
                Utilities.conversationTitle(context, conversation, rec.$1, rec.$2, rec.$3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
        title: Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
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
            Text(AppLocalizations.of(context)!.selectedChatsCount(_selectedConversations.length.toString())),
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
              child: Text(AppLocalizations.of(context)!.sendWithCount(_selectedConversations.length.toString())),
            ),
          ],
        ),
      ),
    );
  }
}
