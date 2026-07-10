import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/utils/layout_scale.dart';
import '../default_portrait_provider.dart';
import '../user_info_widget.dart';
import 'model/employee.dart';
import 'model/organization.dart';
import 'organization_view_model.dart';
import 'package:chat/theme/app_colors.dart';

class OrganizationScreen extends StatefulWidget {
  final int? initialOrganizationId;
  final bool selectMode;
  final int maxSelected;
  final List<String>? disabledUserIds;
  final List<String>? initialSelectedUserIds;
  final ValueChanged<List<String>>? onSelected;
  final bool showBackOnRoot;

  const OrganizationScreen({
    super.key,
    this.initialOrganizationId,
    this.selectMode = false,
    this.maxSelected = 1024,
    this.disabledUserIds,
    this.initialSelectedUserIds,
    this.onSelected,
    this.showBackOnRoot = false,
  });

  @override
  _OrganizationScreenState createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  late OrganizationViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedUserIds;

  @override
  void initState() {
    super.initState();
    _selectedUserIds = Set<String>.from(widget.initialSelectedUserIds ?? []);
    _viewModel = OrganizationViewModel();
    _viewModel.loadInitialData(organizationId: widget.initialOrganizationId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Widget _buildBreadcrumbs() {
    return Consumer<OrganizationViewModel>(
      builder: (context, viewModel, child) {
        final path = viewModel.breadcrumbPath;
        if (path.isEmpty) return const SizedBox.shrink();

        List<Widget> items = [];
        // 根入口，点击关闭页面
        items.add(
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                '组织架构',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Icon(Icons.chevron_right, size: 18.0, color: context.colors.textSecondary),
        ));

        for (int i = 0; i < path.length; i++) {
          final org = path[i];
          final isLast = i == path.length - 1;
          items.add(
            InkWell(
              onTap: isLast
                  ? null
                  : () => viewModel.navigateToOrganization(org),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: Text(
                  org.name,
                  style: TextStyle(
                    color: isLast
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
          if (!isLast) {
            items.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(Icons.chevron_right, size: 18.0, color: context.colors.textSecondary),
            ));
          }
        }

        return Container(
          // 浅色下 chatBg 与原来的 Colors.grey[100] 同为 #F5F5F5,两端可以合并成一个令牌
          color: context.colors.chatBg,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(children: items),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Consumer<OrganizationViewModel>(
      builder: (context, viewModel, child) {
        final colors = context.colors;
        return Container(
          color: isDesktopShell ? colors.chatBg : null,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktopShell ? 12.0 : 16.0,
            vertical: isDesktopShell ? 8.0 : 12.0,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => viewModel.search(value),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '搜索成员',
              hintStyle: TextStyle(color: colors.textSecondary),
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        viewModel.clearSearch();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isDesktopShell ? 6.0 : 8.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              // 桌面端输入框浮在 chatBg 上,取 surface 才有层次;
              // 移动端输入框嵌在 surface 页面里,要往下压一档。
              fillColor: isDesktopShell ? colors.surface : colors.inputBg,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      alignment: Alignment.centerLeft,
      color: context.colors.chatBg,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: context.colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool _isDisabled(String userId) {
    return widget.disabledUserIds?.contains(userId) ?? false;
  }

  void _toggleEmployeeSelection(String userId) {
    if (_selectedUserIds.contains(userId)) {
      setState(() {
        _selectedUserIds.remove(userId);
      });
      return;
    }

    if (_isDisabled(userId)) return;

    if (_selectedUserIds.length >= widget.maxSelected) {
      Fluttertoast.showToast(msg: '最多选择 ${widget.maxSelected} 人');
      return;
    }

    setState(() {
      _selectedUserIds.add(userId);
    });
  }

  void _onDone() {
    final result = _selectedUserIds.toList();
    if (widget.onSelected != null) {
      widget.onSelected!(result);
    }
    Navigator.of(context).pop(result);
  }

  Widget _buildSubOrgTile(Organization subOrg) {
    final name = '${subOrg.name}(${subOrg.memberCount ?? 0})';
    final baseHeight = isDesktopShell ? 48.0 : 56.0;
    return Container(
      constraints: BoxConstraints(
        minHeight: LayoutScale.watchScale(context, baseHeight, cap: LayoutScale.rowCap),
      ),
      child: ListTile(
        leading: Icon(
          Icons.corporate_fare,
          color: Theme.of(context).colorScheme.secondary,
          size: LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap),
        ),
        title: Text(name),
        trailing: Icon(
          Icons.chevron_right,
          size: LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap),
        ),
        visualDensity: isDesktopShell ? VisualDensity.compact : VisualDensity.standard,
        onTap: () => _viewModel.navigateToOrganization(subOrg),
      ),
    );
  }

  Widget _buildEmployeeTile(Employee emp) {
    final isSelected = _selectedUserIds.contains(emp.employeeId);
    final isDisabled = widget.selectMode && _isDisabled(emp.employeeId);

    Widget? trailing;
    VoidCallback? onTap;
    if (widget.selectMode) {
      trailing = Checkbox(
        value: isSelected,
        onChanged: isDisabled ? null : (_) => _toggleEmployeeSelection(emp.employeeId),
      );
      onTap = isDisabled ? null : () => _toggleEmployeeSelection(emp.employeeId);
    } else {
      onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserInfoWidget(emp.employeeId),
          ),
        );
      };
    }

    final hasSubtitle = emp.title != null && emp.title!.isNotEmpty;
    final baseHeight = hasSubtitle
        ? (isDesktopShell ? 64.0 : 72.0)
        : (isDesktopShell ? 48.0 : 56.0);

    return Container(
      constraints: BoxConstraints(
        minHeight: LayoutScale.watchScale(context, baseHeight, cap: LayoutScale.rowCap),
      ),
      child: ListTile(
        leading: Portrait(
          emp.portraitUrl ?? WFPortraitProvider.instance.userDefaultPortrait(emp.toUserInfo()),
          Config.defaultUserPortrait,
        ),
        title: Text(emp.name),
        subtitle: hasSubtitle ? Text(emp.title!) : null,
        trailing: trailing,
        visualDensity: isDesktopShell ? VisualDensity.compact : VisualDensity.standard,
        onTap: onTap,
      ),
    );
  }

  Widget _buildOrganizationList(OrganizationViewModel viewModel) {
    final details = viewModel.currentOrganizationDetails;
    if (details == null) {
      return const Expanded(
        child: Center(child: Text('No organization data available.')),
      );
    }

    final subOrgs = details.subOrganizations ?? [];
    final employees = details.employees ?? [];

    if (subOrgs.isEmpty && employees.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
            child: Text(
              '该部门暂无子部门或成员',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 0.0),
        children: [
          if (subOrgs.isNotEmpty) ...[
            _buildSectionHeader('子部门'),
            ...subOrgs.map(_buildSubOrgTile),
          ],
          if (employees.isNotEmpty) ...[
            _buildSectionHeader('成员'),
            ...employees.map(_buildEmployeeTile),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(OrganizationViewModel viewModel) {
    if (viewModel.isSearching) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.searchError != null) {
      return Expanded(
        child: Center(
          child: Text(
            viewModel.searchError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      );
    }

    if (viewModel.searchResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            '未找到匹配的成员',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 0.0),
        children: viewModel.searchResults.map(_buildEmployeeTile).toList(),
      ),
    );
  }

  Widget _buildDoneAction() {
    final label = _selectedUserIds.isEmpty
        ? '确定'
        : '确定(${_selectedUserIds.length}/${widget.maxSelected})';
    return TextButton(
      onPressed: _onDone,
      style: TextButton.styleFrom(
        foregroundColor: isDesktopShell ? context.colors.accent : null,
        textStyle: isDesktopShell ? const TextStyle(fontSize: 14) : null,
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<OrganizationViewModel>(
        builder: (context, viewModel, child) {
          return PopScope(
            canPop: !_viewModel.canNavigateBackInHierarchy(),
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _viewModel.canNavigateBackInHierarchy()) {
                _viewModel.navigateBackInHierarchy();
              }
            },
            child: Scaffold(
              appBar: isDesktopShell
                  ? PcPageHeader(
                      title: viewModel.appBarTitle ?? '组织结构',
                      onBack: (viewModel.canNavigateBackInHierarchy() || widget.showBackOnRoot)
                          ? () => Navigator.of(context).maybePop()
                          : null,
                      actions: widget.selectMode ? [_buildDoneAction()] : null,
                    )
                  : AppBar(
                      title: Text(viewModel.appBarTitle ?? '组织结构'),
                      actions: widget.selectMode ? [_buildDoneAction()] : null,
                    ),
              backgroundColor: isDesktopShell ? context.colors.chatBg : null,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumbs(),
                  const Divider(height: 1),
                  _buildSearchBar(),
                  if (viewModel.isLoading && viewModel.searchQuery.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (viewModel.error != null && viewModel.searchQuery.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: context.colors.danger, size: 44),
                              const SizedBox(height: 12),
                              Text(viewModel.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('重新加载'),
                                onPressed: () => viewModel.retryLoadData(),
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (viewModel.searchQuery.isNotEmpty)
                    _buildSearchResults(viewModel)
                  else
                    _buildOrganizationList(viewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
