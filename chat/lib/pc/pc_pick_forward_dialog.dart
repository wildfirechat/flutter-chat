import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/conversation/forward/forward_target_controller.dart';
import 'package:chat/conversation/forward/pick_forward_page.dart' show OnForwardTargetsSelected;
import 'package:chat/conversation/forward/widgets/conversation_display.dart';
import 'package:chat/conversation/forward/widgets/forward_message_preview.dart';
import 'package:chat/conversation/forward/widgets/forward_search_bar.dart';
import 'package:chat/conversation/forward/widgets/forward_target_list.dart';
import 'package:chat/conversation/forward/widgets/selected_avatar_tile.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/viewmodel/search_view_model.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_typography.dart';


/// 桌面端转发弹窗:左栏选目标,右栏确认发送。
///
/// 建群不跳走:左栏换成好友列表,右栏换成“创建并发送”,建完群直接把消息发过去并关窗。
class PcPickForwardView extends StatefulWidget {
  final OnForwardTargetsSelected onSelected;
  final List<Message>? messages;
  final bool oneByOne;

  const PcPickForwardView({super.key, required this.onSelected, this.messages, this.oneByOne = false});

  @override
  State<PcPickForwardView> createState() => _PcPickForwardViewState();
}

class _PcPickForwardViewState extends State<PcPickForwardView> {
  final ForwardTargetController _controller = ForwardTargetController(multiSelect: true);
  final SearchViewModel _searchViewModel = SearchViewModel();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  final ScrollController _memberScrollController = ScrollController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text);
      if (_searchText.isNotEmpty) {
        _searchViewModel.search(_searchText, searchTypes: ForwardTargetList.searchTypes);
      }
    });
    _memberSearchController.addListener(() {
      _controller.pickUserViewModel?.search(_memberSearchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _commentController.dispose();
    _memberSearchController.dispose();
    _memberScrollController.dispose();
    _searchViewModel.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? get _comment => _commentController.text.isEmpty ? null : _commentController.text;

  void _onTargetTap(Conversation conversation) => _controller.toggleSelection(conversation);

  void _clearMemberSearch() {
    if (_memberSearchController.text.isNotEmpty) {
      _memberSearchController.clear();
    }
  }

  void _exitMemberSelection() {
    _memberSearchController.clear();
    _controller.exitMemberSelection();
  }

  /// 建群后直接把消息转发到新群并关闭弹窗,不回到会话选择列表。
  void _createGroupAndSend(List<UserInfo> pickedUsers) async {
    if (_controller.creatingGroup) return;

    final l10n = AppLocalizations.of(context)!;
    if (pickedUsers.isEmpty) {
      showToast(msg: l10n.pickContactsToCreateGroup);
      return;
    }

    // 只选中一位好友时直接发到单聊,无需建群
    if (pickedUsers.length == 1) {
      widget.onSelected([Conversation(conversationType: ConversationType.Single, target: pickedUsers[0].userId, line: 0)], _comment);
      return;
    }

    final result = await _controller.createGroup(pickedUsers, etcNameBuilder: l10n.groupNameEtc);
    if (!mounted) return;
    if (!result.isSuccess) {
      showToast(msg: l10n.createGroupFail('${result.errorCode}'));
      return;
    }

    widget.onSelected([Conversation(conversationType: ConversationType.Group, target: result.groupId!, line: 0)], _comment);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) =>
          _controller.isSelectingMembers ? _buildMemberSelection(context) : _buildTargetSelection(context),
    );
  }

  Widget _buildShell(BuildContext context, {required Widget left, required Widget right}) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.colors.hairlineSoft, width: 0.5)),
            ),
            child: left,
          ),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _buildTargetSelection(BuildContext context) {
    return _buildShell(context, left: _buildTargetColumn(context), right: _buildForwardPanel(context));
  }

  /// 两栏都依赖已选成员,统一挂在一个 Consumer 下,勾选后左右同时刷新。
  Widget _buildMemberSelection(BuildContext context) {
    final pickUserViewModel = _controller.pickUserViewModel;
    if (pickUserViewModel == null) {
      return _buildShell(
        context,
        left: Column(
          children: [
            _buildBackBar(context),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        right: _buildCreateGroupPanel(context, null),
      );
    }

    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: pickUserViewModel,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) => _buildShell(
          context,
          left: _buildMemberColumn(context, viewModel),
          right: _buildCreateGroupPanel(context, viewModel),
        ),
      ),
    );
  }

  // ---- 左栏 ----

  Widget _buildTargetColumn(BuildContext context) {
    return Column(
      children: [
        ForwardSearchBar(controller: _searchController),
        Expanded(
          child: ForwardTargetList(
            controller: _controller,
            searchViewModel: _searchViewModel,
            searchText: _searchText,
            onTargetTap: _onTargetTap,
            onCreateGroupTap: _controller.enterMemberSelection,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberColumn(BuildContext context, PickUserViewModel viewModel) {
    return Column(
      children: [
        _buildBackBar(context),
        ForwardSearchBar(controller: _memberSearchController),
        Expanded(
          child: viewModel.userList.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noSearchResult,
                    style: AppText.sm.copyWith(color: context.colors.textSecondary, decoration: TextDecoration.none),
                  ),
                )
              : ListView.builder(
                  controller: _memberScrollController,
                  itemCount: viewModel.userList.length,
                  itemBuilder: (context, i) => SelectableUserItem(
                    viewModel.userList[i],
                    1024,
                    null,
                    onUserPicked: _clearMemberSearch,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBackBar(BuildContext context) {
    return InkWell(
      onTap: _exitMemberSelection,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.hairlineSoft, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_back_ios_new, size: 14, color: context.colors.textSecondary),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.createGroupChat,
              style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: context.colors.textPrimary, decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 右栏 ----

  Widget _buildForwardPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _controller.selectedConversations;
    return _buildPanel(
      context,
      title: widget.oneByOne ? l10n.forwardSendSeparately : l10n.forwardSendMerged,
      subtitle: l10n.selectedChatsCount('${selected.length}'),
      emptyHint: l10n.pickTargetsFromLeft,
      tiles: selected
          .map((conversation) => ConversationDisplay(
                conversation: conversation,
                builder: (context, info) => SelectedListTile(
                  portrait: info.portrait,
                  defaultPortrait: info.defaultPortrait,
                  name: info.title,
                  onRemove: () => _controller.toggleSelection(conversation),
                ),
              ))
          .toList(),
      action: FilledButton(
        onPressed: _controller.hasSelection ? () => widget.onSelected(selected, _comment) : null,
        child: Text(l10n.send),
      ),
    );
  }

  /// [viewModel] 为 null 表示好友列表仍在加载,此时右栏显示空态、主操作禁用。
  Widget _buildCreateGroupPanel(BuildContext context, PickUserViewModel? viewModel) {
    final l10n = AppLocalizations.of(context)!;
    final pickedUsers = viewModel?.pickedUsers ?? const <UserInfo>[];

    return _buildPanel(
      context,
      title: l10n.createGroupChat,
      subtitle: l10n.selectedContactsCount('${pickedUsers.length}'),
      emptyHint: l10n.pickContactsToCreateGroup,
      tiles: pickedUsers
          .map((user) => SelectedListTile(
                portrait: user.portrait ?? Config.defaultUserPortrait,
                defaultPortrait: Config.defaultUserPortrait,
                name: MeshUserDisplay.getReadableName(user),
                onRemove: () => viewModel!.pickUser(user, false),
              ))
          .toList(),
      action: FilledButton(
        onPressed: (pickedUsers.isNotEmpty && !_controller.creatingGroup)
            ? () => _createGroupAndSend(List<UserInfo>.from(pickedUsers))
            : null,
        // 建群中按钮已禁用(灰底),spinner 用默认主色。
        child: _controller.creatingGroup
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l10n.createAndSend),
      ),
    );
  }

  /// 转发确认与建群并发送共用的右栏骨架:标题 / 已选方格 / 消息预览 / 留言 / 取消+主操作。
  Widget _buildPanel(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String emptyHint,
    required List<Widget> tiles,
    required Widget action,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppText.lg.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary, decoration: TextDecoration.none),
                ),
                Text(
                  subtitle,
                  style: AppText.xs.copyWith(color: colors.textSecondary, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          Divider(color: colors.hairlineSoft, height: 1),
          Expanded(
            flex: 3,
            child: tiles.isEmpty
                ? Center(
                    child: Text(
                      emptyHint,
                      style: AppText.sm.copyWith(color: colors.textSecondary, decoration: TextDecoration.none),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: tiles,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ForwardMessagePreview(messages: widget.messages, oneByOne: widget.oneByOne),
                const SizedBox(height: 16),
                _buildCommentField(context),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: colors.hairlineSoft, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 12),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentField(BuildContext context) {
    final colors = context.colors;
    final underline = UnderlineInputBorder(borderSide: BorderSide(color: colors.hairlineSoft, width: 0.5));
    return TextField(
      controller: _commentController,
      style: AppText.sm,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.leaveMessage,
        hintStyle: AppText.sm.copyWith(color: colors.textSecondary),
        border: underline,
        enabledBorder: underline,
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.accent, width: 1.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}
