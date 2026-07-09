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

const Color _accent = Color(0xFF3B62E0);
const Color _accentDisabled = Color(0xFFA8BDFF);
const Color _hairline = Color(0xFFEBEBEB);
const Color _divider = Color(0xFFF0F0F0);

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

  Widget _buildShell({required Widget left, required Widget right}) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _hairline, width: 0.5)),
            ),
            child: left,
          ),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _buildTargetSelection(BuildContext context) {
    return _buildShell(left: _buildTargetColumn(context), right: _buildForwardPanel(context));
  }

  /// 两栏都依赖已选成员,统一挂在一个 Consumer 下,勾选后左右同时刷新。
  Widget _buildMemberSelection(BuildContext context) {
    final pickUserViewModel = _controller.pickUserViewModel;
    if (pickUserViewModel == null) {
      return _buildShell(
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
                    style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.none),
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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _divider, width: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_new, size: 14, color: Color(0xFF666666)),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.createGroupChat,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333), decoration: TextDecoration.none),
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
                builder: (context, info) => SelectedAvatarTile(
                  portrait: info.portrait,
                  defaultPortrait: info.defaultPortrait,
                  name: info.title,
                  onRemove: () => _controller.toggleSelection(conversation),
                ),
              ))
          .toList(),
      action: ElevatedButton(
        onPressed: _controller.hasSelection ? () => widget.onSelected(selected, _comment) : null,
        style: _actionButtonStyle,
        child: Text(l10n.send, style: const TextStyle(fontSize: 13)),
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
          .map((user) => SelectedAvatarTile(
                portrait: user.portrait ?? Config.defaultUserPortrait,
                defaultPortrait: Config.defaultUserPortrait,
                name: user.displayName ?? user.userId,
                onRemove: () => viewModel!.pickUser(user, false),
              ))
          .toList(),
      action: ElevatedButton(
        onPressed: (pickedUsers.isNotEmpty && !_controller.creatingGroup)
            ? () => _createGroupAndSend(List<UserInfo>.from(pickedUsers))
            : null,
        style: _actionButtonStyle,
        child: _controller.creatingGroup
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l10n.createAndSend, style: const TextStyle(fontSize: 13)),
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
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333), decoration: TextDecoration.none),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          const Divider(color: _divider, height: 1),
          Expanded(
            flex: 3,
            child: tiles.isEmpty
                ? Center(
                    child: Text(
                      emptyHint,
                      style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.none),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Wrap(spacing: 8, runSpacing: 8, children: tiles),
                    ),
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
          const Divider(color: _divider, height: 1),
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
                  child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF333333), fontSize: 13)),
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
    return TextField(
      controller: _commentController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.leaveMessage,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: _hairline, width: 0.5)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _hairline, width: 0.5)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _accent, width: 1.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }

  static final ButtonStyle _actionButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: _accent,
    disabledBackgroundColor: _accentDisabled,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
}
