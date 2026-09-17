import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart' show OnPickUserCallback;
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_organization_pick_column.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_pick_list.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面端多选联系人的分栏形态(参照微信 PC):
/// 左栏为可搜索的联系人列表(勾选框 + 分类字母段),右栏为「已选择」清单(可逐个移除),
/// 底部统一的取消/完成操作栏。用于发起群聊、群会话添加/移除成员、群通话选人等场景。
///
/// 「从组织架构选择」不再 push 新页面,而是在左栏原地切换为组织架构浏览器
/// ([PcOrganizationPickColumn]),勾选结果与联系人共用同一份 pickedUsers,右栏「已选择」实时同步。
///
/// 本视图仅承担 UI;选人后的动作(建群、加人、踢人…)仍由 [callback] 决定,并负责关闭
/// 承载本视图的 Dialog。语义与移动端 PickUserScreen 一致:candidates 决定候选来源,
/// disabledChecked/​disabledUnchecked 为不可切换的预置项。
class PcPickUserView extends StatefulWidget {
  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  final bool showMentionAll;
  final bool showOrganizationEntry;

  const PcPickUserView(
    this.callback, {
    required this.title,
    this.maxSelected = 1024,
    this.candidates,
    this.disabledCheckedUsers,
    this.disabledUncheckedUsers,
    this.showMentionAll = false,
    this.showOrganizationEntry = true,
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

  // 左栏是否处于组织架构浏览模式;组织 VM 首次进入时懒加载。
  bool _orgMode = false;
  OrganizationViewModel? _orgViewModel;

  // 白底弹窗上的行悬停高亮:比中栏灰列表更浅,避免脏灰感。

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
    _orgViewModel?.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _initData() async {
    var userInfos = widget.candidates != null
        ? await Imclient.getUserInfos(widget.candidates!)
        : await UserRepo.getFriendUserInfos();
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

  void _enterOrgMode() {
    if (_orgViewModel == null) {
      _orgViewModel = OrganizationViewModel();
      _orgViewModel!.loadInitialData();
    }
    setState(() => _orgMode = true);
  }

  void _exitOrgMode() => setState(() => _orgMode = false);

  @override
  Widget build(BuildContext context) {
    context.watch<FontSizeViewModel>();
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
                    Expanded(
                        child: _orgMode
                            ? PcOrganizationPickColumn(
                                orgViewModel: _orgViewModel!,
                                pickViewModel: viewModel,
                                onBack: _exitOrgMode,
                              )
                            : _buildContactsColumn(context, viewModel)),
                    VerticalDivider(
                        width: 0.5,
                        thickness: 0.5,
                        color: context.colors.hairline),
                    SizedBox(
                        width: 240,
                        child: _buildRightColumn(context, viewModel)),
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
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(width: 0.5, color: context.colors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: PcTheme.paneTitle(context),
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
                  color: hovered
                      ? context.colors.hoverOverlay
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.close,
                    size: 18, color: context.colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 左栏:联系人模式 ----

  Widget _buildContactsColumn(
      BuildContext context, PickUserViewModel viewModel) {
    return Column(
      children: [
        PcPickSearchField(
          controller: _searchController,
          hint: AppLocalizations.of(context)!.search,
          onChanged: viewModel.search,
        ),
        if (widget.showOrganizationEntry && !viewModel.isSearching)
          PcOrganizationPickEntry(onTap: _enterOrgMode),
        const Divider(),
        Expanded(child: _buildContactList(context, viewModel)),
      ],
    );
  }

  Widget _buildContactList(BuildContext context, PickUserViewModel viewModel) {
    final users = viewModel.userList;
    return ListView.builder(
      controller: _listController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: users.length,
      itemBuilder: (context, i) =>
          _buildContactTile(context, viewModel, users[i]),
    );
  }

  Widget _buildContactTile(
      BuildContext context, PickUserViewModel viewModel, UIPickUserInfo item) {
    final l10n = AppLocalizations.of(context)!;
    final userInfo = item.userInfo;
    final userId = userInfo.userId;
    final bool showCategory = item.showCategory && !viewModel.isSearching;
    final bool checkable = viewModel.isCheckable(userId);
    // 预置的既有成员(disabledChecked)呈现为选中+置灰,不可取消;disabledUnchecked 呈现为置灰未选。
    final bool checked = viewModel.isChecked(userId) ||
        viewModel.disabledAndCheckedUserIds.contains(userId);

    final row = PcCheckableRow(
      checkable: checkable,
      checked: checked,
      onToggle: (value) => _togglePick(context, userInfo, value),
      avatar: userId == '@all'
          ? Image.asset(Config.defaultGroupPortrait,
              width: LayoutScale.watchScale(context, 34.0,
                  cap: LayoutScale.iconCap),
              height: LayoutScale.watchScale(context, 34.0,
                  cap: LayoutScale.iconCap))
          : Portrait(userInfo.portrait ?? Config.defaultUserPortrait,
              Config.defaultUserPortrait,
              width: 34, height: 34),
      title: userId == '@all'
          ? l10n.allMembers
          : MeshUserDisplay.getReadableName(userInfo),
    );

    if (!showCategory) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcPickSectionHeader(item.category == '{'
            ? '#'
            : (item.category == 'AI' ? l10n.aiRobot : item.category)),
        row,
      ],
    );
  }

  // ---- 右栏:已选择 ----

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
            style: AppText.sm.copyWith(color: context.colors.textSecondary),
          ),
        ),
        const Divider(),
        Expanded(
          child: picked.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.pickContactHint,
                      textAlign: TextAlign.center,
                      style: AppText.sm
                          .copyWith(color: context.colors.textTertiary),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _selectedController,
                  itemCount: picked.length,
                  itemBuilder: (context, i) =>
                      _buildSelectedTile(context, viewModel, picked[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedTile(
      BuildContext context, PickUserViewModel viewModel, UserInfo userInfo) {
    final l10n = AppLocalizations.of(context)!;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => viewModel.pickUser(userInfo, false),
        child: Container(
          height:
              LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              userInfo.userId == '@all'
                  ? Image.asset(Config.defaultGroupPortrait,
                      width: LayoutScale.watchScale(context, 30.0,
                          cap: LayoutScale.iconCap),
                      height: LayoutScale.watchScale(context, 30.0,
                          cap: LayoutScale.iconCap))
                  : Portrait(userInfo.portrait ?? Config.defaultUserPortrait,
                      Config.defaultUserPortrait,
                      width: 30, height: 30),
              const SizedBox(width: 10),
              Expanded(
                child: userInfo.userId == '@all'
                    ? Text(
                        l10n.allMembers,
                        style: AppText.sm
                            .copyWith(color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : MeshUserName(
                        userInfo,
                        style: AppText.sm
                            .copyWith(color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              Icon(
                Icons.remove_circle_outline,
                size: LayoutScale.watchScale(context, 18.0,
                    cap: LayoutScale.iconCap),
                color: hovered
                    ? context.colors.badge
                    : context.colors.textTertiary,
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
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(width: 0.5, color: context.colors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: viewModel.pickedUsers.isNotEmpty
                ? () => widget.callback(context,
                    viewModel.pickedUsers.map((u) => u.userId).toList())
                : null,
            child: Text(
                count > 0 ? l10n.doneWithCount(count.toString()) : l10n.done),
          ),
        ],
      ),
    );
  }
}
