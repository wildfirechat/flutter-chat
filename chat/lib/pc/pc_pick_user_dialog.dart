import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart' show OnPickUserCallback;
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/widget/portrait.dart';

/// 桌面端多选联系人的分栏形态(参照微信 PC):
/// 左栏为可搜索的联系人列表(勾选框 + 分类字母段),右栏为「已选择」清单(可逐个移除),
/// 底部统一的取消/完成操作栏。用于发起群聊、群会话添加/移除成员、群通话选人等场景。
///
/// 仅承担 UI;选人后的动作(建群、加人、踢人…)仍由 [callback] 决定,并负责关闭本弹窗
/// (回调中的 Navigator.pop(context) 会关闭承载本视图的 Dialog)。语义与移动端 PickUserScreen
/// 保持一致:candidates 决定候选来源,disabledChecked/​disabledUnchecked 为不可切换的预置项。
class PcPickUserView extends StatefulWidget {
  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  final bool showMentionAll;

  const PcPickUserView(
    this.callback, {
    required this.title,
    this.maxSelected = 1024,
    this.candidates,
    this.disabledCheckedUsers,
    this.disabledUncheckedUsers,
    this.showMentionAll = false,
    super.key,
  });

  @override
  State<PcPickUserView> createState() => _PcPickUserViewState();
}

class _PcPickUserViewState extends State<PcPickUserView> {
  late final PickUserViewModel _viewModel;
  final ScrollController _listController = ScrollController();
  final ScrollController _selectedController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // 白底弹窗上的行悬停高亮:比中栏灰列表更浅,避免脏灰感。
  static const Color _rowHover = Color(0x0A000000);

  @override
  void initState() {
    super.initState();
    _viewModel = PickUserViewModel();
    _initData();
  }

  @override
  void dispose() {
    _listController.dispose();
    _selectedController.dispose();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _initData() async {
    var userInfos = widget.candidates != null ? await Imclient.getUserInfos(widget.candidates!) : await UserRepo.getFriendUserInfos();
    _viewModel.setup(
      userInfos,
      maxPickCount: widget.maxSelected,
      uncheckableUserIds: widget.disabledUncheckedUsers,
      disabledUserIds: widget.disabledCheckedUsers,
      showMentionAll: widget.showMentionAll,
    );
  }

  /// 从搜索结果中勾选后清空搜索,回到完整列表(与移动端一致)。
  void _clearSearchIfNeeded() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _viewModel.search('');
    }
  }

  void _togglePick(BuildContext context, UserInfo userInfo, bool pick) {
    if (!_viewModel.pickUser(userInfo, pick)) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
    } else if (pick) {
      _clearSearchIfNeeded();
    }
  }

  Future<void> _openOrganizationPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final remaining = widget.maxSelected - _viewModel.pickedUsers.length;
    if (remaining <= 0) {
      Fluttertoast.showToast(msg: l10n.maxUserLimit);
      return;
    }
    final selected = _viewModel.pickedUsers.map((u) => u.userId).toList();
    final disabled = <String>{
      ...widget.disabledUncheckedUsers ?? [],
      ...widget.disabledCheckedUsers ?? [],
    }.toList();

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationScreen(
          selectMode: true,
          maxSelected: remaining,
          initialSelectedUserIds: selected,
          disabledUserIds: disabled,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final userInfos = await Imclient.getUserInfos(result);
      for (final userInfo in userInfos) {
        if (_viewModel.pickedUsers.length >= widget.maxSelected) break;
        _viewModel.pickUser(userInfo, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: _viewModel,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildLeftColumn(context, viewModel)),
                    const VerticalDivider(width: 0.5, thickness: 0.5, color: PcTheme.hairline),
                    SizedBox(width: 240, child: _buildRightColumn(context, viewModel)),
                  ],
                ),
              ),
              _buildFooter(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(width: 0.5, color: PcTheme.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: PcTheme.paneTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          HoverBuilder(
            cursor: SystemMouseCursors.click,
            builder: (context, hovered) => GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: hovered ? _rowHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.close, size: 18, color: PcTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, PickUserViewModel viewModel) {
    return Column(
      children: [
        _buildSearchField(context, viewModel),
        if (!viewModel.isSearching) _buildOrganizationEntry(context),
        const Divider(height: 0.5, thickness: 0.5, color: PcTheme.hairline),
        Expanded(child: _buildContactList(context, viewModel)),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, PickUserViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: PcTheme.searchFieldBg,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: PcTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: PcTheme.textPrimary),
                cursorColor: PcTheme.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: AppLocalizations.of(context)!.search,
                  hintStyle: const TextStyle(fontSize: 13, color: PcTheme.textTertiary),
                ),
                onChanged: viewModel.search,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationEntry(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => _openOrganizationPicker(context),
        child: Container(
          height: 44,
          color: hovered ? _rowHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.corporate_fare, size: 20, color: PcTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectFromOrganization,
                  style: const TextStyle(fontSize: 13, color: PcTheme.textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: PcTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactList(BuildContext context, PickUserViewModel viewModel) {
    final users = viewModel.userList;
    return ListView.builder(
      controller: _listController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: users.length,
      itemBuilder: (context, i) => _buildContactTile(context, viewModel, users[i]),
    );
  }

  Widget _buildContactTile(BuildContext context, PickUserViewModel viewModel, UIPickUserInfo item) {
    final l10n = AppLocalizations.of(context)!;
    final userInfo = item.userInfo;
    final userId = userInfo.userId;
    final bool showCategory = item.showCategory && !viewModel.isSearching;
    final bool checkable = viewModel.isCheckable(userId);
    // 预置的既有成员(disabledChecked)呈现为选中+置灰,不可取消;disabledUnchecked 呈现为置灰未选。
    final bool checked = viewModel.isChecked(userId) || viewModel.disabledAndCheckedUserIds.contains(userId);

    final row = HoverBuilder(
      cursor: checkable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, hovered) => GestureDetector(
        onTap: checkable ? () => _togglePick(context, userInfo, !viewModel.isChecked(userId)) : null,
        child: Container(
          height: 48,
          color: checkable && hovered ? _rowHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: checkable ? (value) => _togglePick(context, userInfo, value!) : null,
              ),
              const SizedBox(width: 10),
              userId == '@all'
                  ? Image.asset(Config.defaultGroupPortrait, width: 34, height: 34)
                  : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 34, height: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: checkable ? 1.0 : 0.5,
                  child: Text(
                    userId == '@all' ? l10n.allMembers : userInfo.displayName ?? userId,
                    style: const TextStyle(fontSize: 13, color: PcTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showCategory) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 24,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            item.category == '{' ? '#' : (item.category == 'AI' ? l10n.aiRobot : item.category),
            style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary),
          ),
        ),
        row,
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, PickUserViewModel viewModel) {
    final l10n = AppLocalizations.of(context)!;
    final picked = viewModel.pickedUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 52,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.pickedCount(picked.length.toString()),
            style: const TextStyle(fontSize: 13, color: PcTheme.textSecondary),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: PcTheme.hairline),
        Expanded(
          child: picked.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.pickContactHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: PcTheme.textTertiary),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _selectedController,
                  itemCount: picked.length,
                  itemBuilder: (context, i) => _buildSelectedTile(context, viewModel, picked[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedTile(BuildContext context, PickUserViewModel viewModel, UserInfo userInfo) {
    final l10n = AppLocalizations.of(context)!;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => viewModel.pickUser(userInfo, false),
        child: Container(
          height: 48,
          color: hovered ? _rowHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              userInfo.userId == '@all'
                  ? Image.asset(Config.defaultGroupPortrait, width: 30, height: 30)
                  : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 30, height: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  userInfo.userId == '@all' ? l10n.allMembers : userInfo.displayName ?? userInfo.userId,
                  style: const TextStyle(fontSize: 13, color: PcTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: hovered ? PcTheme.badgeRed : PcTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, PickUserViewModel viewModel) {
    final l10n = AppLocalizations.of(context)!;
    final count = viewModel.pickedUsers.length;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(width: 0.5, color: PcTheme.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: PcTheme.textPrimary,
              side: const BorderSide(color: PcTheme.hairline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => widget.callback(context, viewModel.pickedUsers.map((u) => u.userId).toList()),
            style: FilledButton.styleFrom(
              backgroundColor: PcTheme.accent,
              disabledBackgroundColor: PcTheme.accent.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(count > 0 ? l10n.doneWithCount(count.toString()) : l10n.done),
          ),
        ],
      ),
    );
  }
}
