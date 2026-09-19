import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/organization/model/employee.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_pick_list.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/widget/portrait.dart';

/// 桌面端选人列表里的「从组织架构选择」入口行。
class PcOrganizationPickEntry extends StatelessWidget {
  final VoidCallback onTap;

  const PcOrganizationPickEntry({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          height:
              LayoutScale.watchScale(context, 44.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.corporate_fare,
                  size: LayoutScale.watchScale(context, 20.0,
                      cap: LayoutScale.iconCap),
                  color: context.colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectFromOrganization,
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right,
                  size: LayoutScale.watchScale(context, 18.0,
                      cap: LayoutScale.iconCap),
                  color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 桌面端选人弹窗左栏的组织架构浏览器:面包屑下钻 + 成员搜索 + 成员勾选。
///
/// 不 push 新页面,由宿主在左栏原地切换进来。勾选直接写进 [pickViewModel],
/// 与联系人列表共用同一份已选,宿主的「已选」区实时同步。
///
/// [orgViewModel] 由宿主持有并负责释放:退出再进来仍停在上次浏览的部门。
class PcOrganizationPickColumn extends StatefulWidget {
  final OrganizationViewModel orgViewModel;
  final PickUserViewModel pickViewModel;

  /// 面包屑最左侧的返回键,回到联系人列表。回调前已清掉组织架构搜索。
  final VoidCallback onBack;

  const PcOrganizationPickColumn({
    super.key,
    required this.orgViewModel,
    required this.pickViewModel,
    required this.onBack,
  });

  @override
  State<PcOrganizationPickColumn> createState() =>
      _PcOrganizationPickColumnState();
}

class _PcOrganizationPickColumnState extends State<PcOrganizationPickColumn> {
  // 搜索词以 VM 为准:重新进入时输入框与 VM 里残留的搜索保持一致。
  late final TextEditingController _searchController =
      TextEditingController(text: widget.orgViewModel.searchQuery);
  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _back() {
    _searchController.clear();
    widget.orgViewModel.clearSearch();
    widget.onBack();
  }

  void _toggleEmployee(Employee emp) {
    final pickViewModel = widget.pickViewModel;
    final id = emp.employeeId;
    if (!pickViewModel.isCheckable(id)) return;
    // 员工不一定在 IM 本地库里,直接用组织架构的姓名/头像构造 UserInfo。
    if (!pickViewModel.pickUser(
        emp.toUserInfo(), !pickViewModel.isChecked(id))) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.orgViewModel, widget.pickViewModel]),
      builder: (context, _) => Column(
        children: [
          _buildBreadcrumb(context),
          PcPickSearchField(
            controller: _searchController,
            hint: AppLocalizations.of(context)!.searchOrgMembers,
            onChanged: widget.orgViewModel.search,
          ),
          const Divider(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final orgViewModel = widget.orgViewModel;
    final path = orgViewModel.breadcrumbPath;
    final List<Widget> items = [
      HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: _back,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: hovered ? context.colors.hoverOverlay : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.arrow_back,
                size: 16, color: context.colors.textPrimary),
          ),
        ),
      ),
    ];

    for (int i = 0; i < path.length; i++) {
      final org = path[i];
      final isLast = i == path.length - 1;
      items.add(Icon(Icons.chevron_right,
          size: 16, color: context.colors.textTertiary));
      items.add(
        HoverBuilder(
          cursor: isLast ? SystemMouseCursors.basic : SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            onTap:
                isLast ? null : () => orgViewModel.navigateToOrganization(org),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                org.name,
                style: AppText.sm.copyWith(
                    color: isLast
                        ? context.colors.textPrimary
                        : context.colors.accent,
                    fontWeight: isLast ? FontWeight.w500 : FontWeight.normal),
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

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orgViewModel = widget.orgViewModel;
    if (orgViewModel.searchQuery.isNotEmpty) {
      return _buildSearchResults(context);
    }
    if (orgViewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orgViewModel.error != null) {
      return _buildMessage(context, orgViewModel.error!,
          onRetry: orgViewModel.retryLoadData);
    }

    final details = orgViewModel.currentOrganizationDetails;
    final subOrgs = details?.subOrganizations ?? [];
    final employees = details?.employees ?? [];
    if (subOrgs.isEmpty && employees.isEmpty) {
      return _buildMessage(context, l10n.orgNoSubOrgOrMembers);
    }

    return ListView(
      controller: _listController,
      children: [
        if (subOrgs.isNotEmpty) ...[
          PcPickSectionHeader(l10n.subDepartments),
          ...subOrgs.map((o) => _buildSubOrgTile(context, o)),
        ],
        if (employees.isNotEmpty) ...[
          PcPickSectionHeader(l10n.members),
          ...employees.map((e) => _buildEmployeeTile(context, e)),
        ],
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orgViewModel = widget.orgViewModel;
    if (orgViewModel.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orgViewModel.searchError != null) {
      return _buildMessage(
          context, l10n.searchFailed(orgViewModel.searchError!));
    }
    if (orgViewModel.searchResults.isEmpty) {
      return _buildMessage(context, l10n.noMatchedMembers);
    }
    return ListView(
      controller: _listController,
      children: orgViewModel.searchResults
          .map((e) => _buildEmployeeTile(context, e))
          .toList(),
    );
  }

  Widget _buildMessage(BuildContext context, String message,
      {VoidCallback? onRetry}) {
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
              // 重试是错误态的唯一行动,与其他屏的 retry 一致用实底主行动。
              FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context)!.reload),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubOrgTile(BuildContext context, Organization org) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => widget.orgViewModel.navigateToOrganization(org),
        child: Container(
          height:
              LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 与组织架构页的部门行同图标,见 OrganizationScreen。
              Icon(Icons.domain,
                  size: LayoutScale.watchScale(context, 22.0,
                      cap: LayoutScale.iconCap),
                  color: context.colors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${org.name}(${org.memberCount ?? 0})',
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeTile(BuildContext context, Employee emp) {
    final pickViewModel = widget.pickViewModel;
    final id = emp.employeeId;
    return PcCheckableRow(
      checkable: pickViewModel.isCheckable(id),
      checked: pickViewModel.isChecked(id) ||
          pickViewModel.disabledAndCheckedUserIds.contains(id),
      onToggle: (_) => _toggleEmployee(emp),
      avatar: Portrait(emp.displayPortrait, Config.defaultUserPortrait,
          width: 34, height: 34),
      title: emp.name,
      subtitle: emp.title,
    );
  }
}
