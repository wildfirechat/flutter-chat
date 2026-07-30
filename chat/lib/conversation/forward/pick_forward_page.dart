import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/conversation/forward/forward_target_controller.dart';
import 'package:chat/conversation/forward/widgets/conversation_display.dart';
import 'package:chat/conversation/forward/widgets/forward_search_bar.dart';
import 'package:chat/conversation/forward/widgets/forward_target_list.dart';
import 'package:chat/conversation/forward/widgets/selected_avatar_tile.dart';
import 'package:chat/conversation/forward_confirmation_sheet.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/widget/app_bar_actions.dart';
import 'package:chat/theme/app_typography.dart';

typedef OnForwardTargetsSelected = void Function(
    List<Conversation> targets, String? comment);

/// 移动端转发选目标整页。
///
/// 建群走微信的做法:选完成员建群,退回本页,再由原有的确认弹窗完成转发。
class PickForwardPage extends StatefulWidget {
  final OnForwardTargetsSelected onSelected;
  final List<Message>? messages;
  final bool oneByOne;

  const PickForwardPage(
      {super.key,
      required this.onSelected,
      this.messages,
      this.oneByOne = false});

  @override
  State<PickForwardPage> createState() => _PickForwardPageState();
}

class _PickForwardPageState extends State<PickForwardPage> {
  final ForwardTargetController _controller = ForwardTargetController();
  final SearchViewModel _searchViewModel = SearchViewModel();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchText = '';

  final TextEditingController _memberSearchController = TextEditingController();
  final ScrollController _memberScrollController = ScrollController();
  String _currentLetter = '';
  bool _isTouchingIndex = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text);
      if (_searchText.isNotEmpty) {
        _searchViewModel.search(_searchText,
            searchTypes: ForwardTargetList.searchTypes);
      }
    });
    _memberSearchController.addListener(() {
      _controller.pickUserViewModel?.search(_memberSearchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _memberSearchController.dispose();
    _memberScrollController.dispose();
    _searchViewModel.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---- 选会话 ----

  void _onTargetTap(Conversation conversation) {
    if (_controller.isMultiSelect) {
      _controller.toggleSelection(conversation);
      if (_searchText.isNotEmpty) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    } else {
      _showConfirmationSheet([conversation]);
    }
  }

  void _showConfirmationSheet(List<Conversation> targets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardConfirmationSheet(
        targets: targets,
        messages: widget.messages,
        oneByOne: widget.oneByOne,
        onConfirm: (comment) => widget.onSelected(targets, comment),
      ),
    );
  }

  // ---- 建群选人 ----

  /// 勾选后清空搜索,回到完整列表(与选人页一致)。
  void _clearMemberSearch() {
    if (_memberSearchController.text.isNotEmpty) {
      _memberSearchController.clear();
    }
  }

  void _exitMemberSelection() {
    _memberSearchController.clear();
    _controller.exitMemberSelection();
  }

  /// 建群后退回选会话流程,让原有的确认弹窗接手(与微信一致)。
  void _confirmMemberSelection(List<UserInfo> pickedUsers) async {
    if (_controller.creatingGroup || pickedUsers.isEmpty) return;

    // 只选中一位好友时直接转发到单聊,无需建群
    if (pickedUsers.length == 1) {
      _exitMemberSelection();
      _onTargetTap(Conversation(
          conversationType: ConversationType.Single,
          target: pickedUsers[0].userId,
          line: 0));
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await _controller.createGroup(pickedUsers,
        etcNameBuilder: l10n.groupNameEtc);
    if (!mounted) return;
    if (!result.isSuccess) {
      showToast(msg: l10n.createGroupFail('${result.errorCode}'));
      return;
    }

    _exitMemberSelection();
    _onTargetTap(Conversation(
        conversationType: ConversationType.Group,
        target: result.groupId!,
        line: 0));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => _controller.isSelectingMembers
          ? _buildMemberSelection(context)
          : _buildTargetSelection(context),
    );
  }

  // ---- 选会话形态 ----

  Widget _buildTargetSelection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.chatBg,
      appBar: AppBar(
        title: Text(_controller.isMultiSelect
            ? l10n.pickMultipleChats
            : l10n.pickOneChat),
        actions: [
          AppBarTextAction(
            label: _controller.isMultiSelect
                ? l10n.singleSelect
                : l10n.multiSelect,
            onPressed: _controller.toggleMultiSelect,
          ),
        ],
      ),
      body: Column(
        children: [
          ForwardSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            maxChipsWidth: MediaQuery.of(context).size.width * 0.6,
            chips: _controller.isMultiSelect ? _buildSelectedChips() : const [],
          ),
          Expanded(
            child: ForwardTargetList(
              controller: _controller,
              searchViewModel: _searchViewModel,
              searchText: _searchText,
              onTargetTap: _onTargetTap,
              onCreateGroupTap: _controller.enterMemberSelection,
            ),
          ),
          if (_controller.isMultiSelect) _buildBottomBar(context),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedChips() {
    return _controller.selectedConversations
        .map((conversation) => ConversationDisplay(
              conversation: conversation,
              builder: (context, info) => PortraitChip(
                portrait: info.portrait,
                defaultPortrait: info.defaultPortrait,
                onTap: () => _controller.toggleSelection(conversation),
              ),
            ))
        .toList();
  }

  Widget _buildBottomBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = _controller.selectedConversations.length;
    return Container(
      color: context.colors.surface,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.hairlineSoft)),
        ),
        child: Row(
          children: [
            Text(
              l10n.selectedChatsCount('$count'),
              style: AppText.base.copyWith(color: context.colors.textPrimary),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _controller.hasSelection
                  ? () =>
                      _showConfirmationSheet(_controller.selectedConversations)
                  : null,
              child: Text(l10n.sendWithCount('$count')),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 建群选人形态 ----

  Widget _buildMemberSelection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pickUserViewModel = _controller.pickUserViewModel;

    if (pickUserViewModel == null) {
      return Scaffold(
        backgroundColor: context.colors.chatBg,
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _exitMemberSelection),
          title: Text(l10n.createGroupChat),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: pickUserViewModel,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) {
          final indexList = viewModel.isSearching
              ? <String>[]
              : _buildIndexList(viewModel.userList);
          final canConfirm =
              viewModel.pickedUsers.isNotEmpty && !_controller.creatingGroup;

          return Scaffold(
            backgroundColor: context.colors.chatBg,
            appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _exitMemberSelection),
              title: Text(l10n.createGroupChat),
              actions: [
                AppBarTextAction(
                  label: viewModel.pickedUsers.isNotEmpty
                      ? '${l10n.confirm}(${viewModel.pickedUsers.length})'
                      : l10n.confirm,
                  onPressed: canConfirm
                      ? () => _confirmMemberSelection(
                          List<UserInfo>.from(viewModel.pickedUsers))
                      : null,
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  ForwardSearchBar(
                    controller: _memberSearchController,
                    maxChipsWidth: MediaQuery.of(context).size.width - 140,
                    chips: viewModel.pickedUsers
                        .map((user) => PortraitChip(
                              portrait:
                                  user.portrait ?? Config.defaultUserPortrait,
                              defaultPortrait: Config.defaultUserPortrait,
                              onTap: () => viewModel.pickUser(user, false),
                            ))
                        .toList(),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          controller: _memberScrollController,
                          itemCount: viewModel.userList.length,
                          itemBuilder: (context, i) => SelectableUserItem(
                            viewModel.userList[i],
                            1024,
                            null,
                            onUserPicked: _clearMemberSearch,
                          ),
                        ),
                        if (indexList.isNotEmpty)
                          SidebarIndex(
                            indexList: indexList,
                            onIndexSelected: (tag) =>
                                _jumpToTag(tag, viewModel.userList),
                            onTouch: (tag, isTouching) {
                              setState(() {
                                _currentLetter = tag;
                                _isTouchingIndex = isTouching;
                              });
                            },
                          ),
                        if (_isTouchingIndex) _buildIndexBubble(),
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

  Widget _buildIndexBubble() {
    return Center(
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
            : Text(_currentLetter,
                style: AppText.xxxl.copyWith(color: Colors.white)),
      ),
    );
  }

  List<String> _buildIndexList(List<UIPickUserInfo> userList) {
    final indexList = <String>['↑'];
    for (var user in userList) {
      if (!user.showCategory) continue;
      var category = user.category;
      if (category.startsWith('AI')) continue;
      if (category == '{') category = '#';
      if (!indexList.contains(category)) {
        indexList.add(category);
      }
    }
    return indexList;
  }

  void _jumpToTag(String tag, List<UIPickUserInfo> userList) {
    if (tag == '↑') {
      _memberScrollController.jumpTo(0.0);
      return;
    }
    final targetCategory = tag == '#' ? '{' : tag;

    double offset = 0;
    for (var user in userList) {
      if (user.category == targetCategory) {
        _memberScrollController.jumpTo(offset);
        return;
      }
      offset += user.showCategory ? 70.5 : 52.5;
    }
  }
}
