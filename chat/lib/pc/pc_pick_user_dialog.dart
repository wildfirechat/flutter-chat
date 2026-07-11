import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart' show OnPickUserCallback;
import 'package:chat/organization/model/employee.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
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
/// 「从组织架构选择」不再 push 新页面,而是在左栏原地切换为组织架构浏览器(面包屑下钻 +
/// 成员勾选),勾选结果与联系人共用同一份 pickedUsers,右栏「已选择」实时同步。
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
  final ScrollController _orgListController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orgSearchController = TextEditingController();

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
    _orgListController.dispose();
    _searchController.dispose();
    _orgSearchController.dispose();
    _orgViewModel?.dispose();
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

  void _enterOrgMode() {
    if (_orgViewModel == null) {
      _orgViewModel = OrganizationViewModel();
      _orgViewModel!.loadInitialData();
    }
    setState(() => _orgMode = true);
  }

  void _exitOrgMode() {
    _orgSearchController.clear();
    _orgViewModel?.clearSearch();
    setState(() => _orgMode = false);
  }

  void _toggleOrgEmployee(Employee emp) {
    final id = emp.employeeId;
    if (!_viewModel.isCheckable(id)) return;
    final picked = _viewModel.isChecked(id);
    // 组织成员构造轻量 UserInfo 入选;回调只用到 userId,展示用 name/portrait 足够。
    final userInfo = UserInfo(id)
      ..displayName = emp.name
      ..portrait = emp.portraitUrl;
    if (!_viewModel.pickUser(userInfo, !picked)) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
    }
  }

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
                    Expanded(child: _orgMode ? _buildOrgColumn(context, viewModel) : _buildContactsColumn(context, viewModel)),
                    VerticalDivider(width: 0.5, thickness: 0.5, color: context.colors.hairline),
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(width: 0.5, color: context.colors.hairline)),
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
                  color: hovered ? context.colors.hoverOverlay : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.close, size: 18, color: context.colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 左栏:联系人模式 ----

  Widget _buildContactsColumn(BuildContext context, PickUserViewModel viewModel) {
    return Column(
      children: [
        _buildSearchField(
          controller: _searchController,
          hint: AppLocalizations.of(context)!.search,
          onChanged: viewModel.search,
        ),
        if (widget.showOrganizationEntry && !viewModel.isSearching) _buildOrganizationEntry(context),
        Divider(height: 0.5, thickness: 0.5, color: context.colors.hairline),
        Expanded(child: _buildContactList(context, viewModel)),
      ],
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.inputBg,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.search, size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                style: AppText.sm.copyWith(color: context.colors.textPrimary),
                cursorColor: context.colors.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: AppText.sm.copyWith(color: context.colors.textTertiary),
                ),
                onChanged: onChanged,
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
        onTap: _enterOrgMode,
        child: Container(
          height: LayoutScale.watchScale(context, 44.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.corporate_fare, size: LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap), color: context.colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectFromOrganization,
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right, size: LayoutScale.watchScale(context, 18.0, cap: LayoutScale.iconCap), color: context.colors.textTertiary),
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

    final row = _buildCheckableRow(
      checkable: checkable,
      checked: checked,
      onToggle: (value) => _togglePick(context, userInfo, value),
      avatar: userId == '@all'
          ? Image.asset(Config.defaultGroupPortrait,
              width: LayoutScale.watchScale(context, 34.0, cap: LayoutScale.iconCap),
              height: LayoutScale.watchScale(context, 34.0, cap: LayoutScale.iconCap))
          : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 34, height: 34),
      title: userId == '@all' ? l10n.allMembers : MeshUserDisplay.getReadableName(userInfo),
    );

    if (!showCategory) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(item.category == '{' ? '#' : (item.category == 'AI' ? l10n.aiRobot : item.category)),
        row,
      ],
    );
  }

  /// 联系人 / 组织成员共用的勾选行:勾选框 + 头像 + 名称(可选副标题)。
  Widget _buildCheckableRow({
    required bool checkable,
    required bool checked,
    required ValueChanged<bool> onToggle,
    required Widget avatar,
    required String title,
    String? subtitle,
  }) {
    return HoverBuilder(
      cursor: checkable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, hovered) => GestureDetector(
        onTap: checkable ? () => onToggle(!checked) : null,
        child: Container(
          height: LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: checkable && hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: checkable ? (value) => onToggle(value!) : null,
              ),
              const SizedBox(width: 10),
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: checkable ? 1.0 : 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.sm.copyWith(color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: AppText.xs.copyWith(color: context.colors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Container(
      height: LayoutScale.watchScale(context, 24.0, cap: LayoutScale.textCap),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        text,
        style: AppText.xs.copyWith(color: context.colors.textSecondary),
      ),
    );
  }

  // ---- 左栏:组织架构模式 ----

  Widget _buildOrgColumn(BuildContext context, PickUserViewModel pickViewModel) {
    return ListenableBuilder(
      listenable: _orgViewModel!,
      builder: (context, _) {
        final orgVm = _orgViewModel!;
        return Column(
          children: [
            _buildOrgBreadcrumb(context, orgVm),
            _buildSearchField(
              controller: _orgSearchController,
              hint: '搜索成员',
              onChanged: orgVm.search,
            ),
            Divider(height: 0.5, thickness: 0.5, color: context.colors.hairline),
            Expanded(child: _buildOrgBody(context, orgVm, pickViewModel)),
          ],
        );
      },
    );
  }

  Widget _buildOrgBreadcrumb(BuildContext context, OrganizationViewModel orgVm) {
    final path = orgVm.breadcrumbPath;
    final List<Widget> items = [
      // 返回联系人列表
      HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: _exitOrgMode,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: hovered ? context.colors.hoverOverlay : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.arrow_back, size: 16, color: context.colors.textPrimary),
          ),
        ),
      ),
    ];

    for (int i = 0; i < path.length; i++) {
      final org = path[i];
      final isLast = i == path.length - 1;
      items.add(Icon(Icons.chevron_right, size: 16, color: context.colors.textTertiary));
      items.add(
        HoverBuilder(
          cursor: isLast ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            onTap: isLast ? null : () => orgVm.navigateToOrganization(org),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                org.name,
                style: AppText.sm.copyWith(color: isLast ? context.colors.textPrimary : context.colors.accent, fontWeight: isLast ? FontWeight.w500 : FontWeight.normal),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: items),
      ),
    );
  }

  Widget _buildOrgBody(BuildContext context, OrganizationViewModel orgVm, PickUserViewModel pickViewModel) {
    if (orgVm.isLoading && orgVm.searchQuery.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orgVm.error != null && orgVm.searchQuery.isEmpty) {
      return _buildOrgMessage(orgVm.error!, onRetry: () => orgVm.retryLoadData());
    }
    if (orgVm.searchQuery.isNotEmpty) {
      return _buildOrgSearchResults(context, orgVm, pickViewModel);
    }

    final details = orgVm.currentOrganizationDetails;
    final subOrgs = details?.subOrganizations ?? [];
    final employees = details?.employees ?? [];
    if (subOrgs.isEmpty && employees.isEmpty) {
      return _buildOrgMessage('该部门暂无子部门或成员');
    }

    return ListView(
      controller: _orgListController,
      children: [
        if (subOrgs.isNotEmpty) ...[
          _buildSectionHeader('子部门'),
          ...subOrgs.map((o) => _buildSubOrgTile(context, orgVm, o)),
        ],
        if (employees.isNotEmpty) ...[
          _buildSectionHeader('成员'),
          ...employees.map((e) => _buildOrgEmployeeTile(context, pickViewModel, e)),
        ],
      ],
    );
  }

  Widget _buildOrgSearchResults(BuildContext context, OrganizationViewModel orgVm, PickUserViewModel pickViewModel) {
    if (orgVm.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orgVm.searchError != null) {
      return _buildOrgMessage(orgVm.searchError!);
    }
    if (orgVm.searchResults.isEmpty) {
      return _buildOrgMessage('未找到匹配的成员');
    }
    return ListView(
      controller: _orgListController,
      children: orgVm.searchResults.map((e) => _buildOrgEmployeeTile(context, pickViewModel, e)).toList(),
    );
  }

  Widget _buildOrgMessage(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.sm.copyWith(color: context.colors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  side: BorderSide(color: context.colors.hairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: AppText.sm,
                ),
                child: const Text('重新加载'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubOrgTile(BuildContext context, OrganizationViewModel orgVm, Organization org) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => orgVm.navigateToOrganization(org),
        child: Container(
          height: LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: LayoutScale.watchScale(context, 22.0, cap: LayoutScale.iconCap), color: context.colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${org.name}(${org.memberCount ?? 0})',
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrgEmployeeTile(BuildContext context, PickUserViewModel pickViewModel, Employee emp) {
    final id = emp.employeeId;
    final bool checkable = pickViewModel.isCheckable(id);
    final bool checked = pickViewModel.isChecked(id) || pickViewModel.disabledAndCheckedUserIds.contains(id);
    return _buildCheckableRow(
      checkable: checkable,
      checked: checked,
      onToggle: (_) => _toggleOrgEmployee(emp),
      avatar: Portrait(emp.portraitUrl ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 34, height: 34),
      title: emp.name,
      subtitle: emp.title,
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
        Divider(height: 0.5, thickness: 0.5, color: context.colors.hairline),
        Expanded(
          child: picked.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.pickContactHint,
                      textAlign: TextAlign.center,
                      style: AppText.sm.copyWith(color: context.colors.textTertiary),
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
          height: LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              userInfo.userId == '@all'
                  ? Image.asset(Config.defaultGroupPortrait,
                      width: LayoutScale.watchScale(context, 30.0, cap: LayoutScale.iconCap),
                      height: LayoutScale.watchScale(context, 30.0, cap: LayoutScale.iconCap))
                  : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 30, height: 30),
              const SizedBox(width: 10),
                Expanded(
                  child: userInfo.userId == '@all'
                      ? Text(
                          l10n.allMembers,
                          style: AppText.sm.copyWith(color: context.colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : MeshUserName(
                          userInfo,
                          style: AppText.sm.copyWith(color: context.colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              Icon(
                Icons.remove_circle_outline,
                size: LayoutScale.watchScale(context, 18.0, cap: LayoutScale.iconCap),
                color: hovered ? context.colors.badge : context.colors.textTertiary,
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
        border: Border(top: BorderSide(width: 0.5, color: context.colors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.hairline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle: AppText.sm,
            ),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => widget.callback(context, viewModel.pickedUsers.map((u) => u.userId).toList()),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.accent,
              disabledBackgroundColor: context.colors.accent.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              textStyle: AppText.sm,
            ),
            child: Text(count > 0 ? l10n.doneWithCount(count.toString()) : l10n.done),
          ),
        ],
      ),
    );
  }
}
