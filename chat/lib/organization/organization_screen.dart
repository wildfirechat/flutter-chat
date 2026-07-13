import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
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
import 'package:chat/theme/app_typography.dart';

class OrganizationScreen extends StatefulWidget {
  final int? initialOrganizationId;
  final bool selectMode;
  final int maxSelected;
  final List<String>? disabledUserIds;
  final List<String>? disabledCheckedUserIds;
  final List<String>? initialSelectedUserIds;
  final ValueChanged<List<String>>? onSelected;

  const OrganizationScreen({
    super.key,
    this.initialOrganizationId,
    this.selectMode = false,
    this.maxSelected = 1024,
    this.disabledUserIds,
    this.disabledCheckedUserIds,
    this.initialSelectedUserIds,
    this.onSelected,
  });

  @override
  _OrganizationScreenState createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  late OrganizationViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedUserIds;

  /// 面包屑横向滚动。层级一深,末级(当前部门)会被顶到可视区右边外面 ——
  /// 每次层级变化后把它滚到最右,保证"我在哪"始终看得见。
  final ScrollController _breadcrumbScrollController = ScrollController();
  int _breadcrumbDepth = 0;

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
    _breadcrumbScrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// 层级变化后把面包屑滚到最右,让末级(当前部门)露出来。
  /// 只在深度真的变了时才滚,否则每次重建都会把用户手动滚过的位置拽回去。
  void _keepCurrentCrumbVisible(int depth) {
    if (depth == _breadcrumbDepth) return;
    _breadcrumbDepth = depth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_breadcrumbScrollController.hasClients) return;
      _breadcrumbScrollController.animateTo(
        _breadcrumbScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// [inHeader] 为 true 时这条面包屑就是桌面端的标题栏内容(替代原来那个静态标题):
  /// 它说的正是"当前在哪个部门",标题栏再写一遍就是重复。因此根层级也必须有东西显示,
  /// 不能像移动端正文里的面包屑条那样在无路径时收起来。
  Widget _buildBreadcrumbs({bool inHeader = false}) {
    return Consumer<OrganizationViewModel>(
      builder: (context, viewModel, child) {
        final path = viewModel.breadcrumbPath;
        _keepCurrentCrumbVisible(path.length);
        if (path.isEmpty && !inHeader) return const SizedBox.shrink();

        final bool atRoot = path.isEmpty;
        List<Widget> items = [];
        // 根入口。在根层级它就是"当前位置",按末级样式渲染且不可点;
        // 进到下级后才变成可点的链接(点击退回上一级)。
        items.add(
          InkWell(
            onTap: atRoot ? null : () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                AppLocalizations.of(context)!.organization,
                style: AppText.base.copyWith(
                  color: atRoot ? context.colors.textPrimary : Theme.of(context).colorScheme.primary,
                  fontWeight: atRoot ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
        if (!atRoot) {
          items.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(Icons.chevron_right, size: 18.0, color: context.colors.textSecondary),
          ));
        }

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
                  style: AppText.base.copyWith(color: isLast
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Theme.of(context).colorScheme.primary, fontWeight: isLast ? FontWeight.bold : FontWeight.normal),
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

        // 层级深了横向滚动,不换行、不挤压标题栏的高度。
        final crumbs = SingleChildScrollView(
          controller: _breadcrumbScrollController,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inHeader ? 0.0 : 8.0, vertical: 4.0),
            child: Row(children: items),
          ),
        );
        if (inHeader) {
          // 底色与内边距由 PcPageHeader 交代。
          return crumbs;
        }
        return Container(
          // 浅色下 chatBg 与原来的 Colors.grey[100] 同为 #F5F5F5,两端可以合并成一个令牌
          color: context.colors.chatBg,
          child: crumbs,
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Consumer<OrganizationViewModel>(
      builder: (context, viewModel, child) {
        final colors = context.colors;
        return Container(
          color: isDesktopShell ? colors.chatBgDesktop : null,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktopShell ? 12.0 : 16.0,
            vertical: isDesktopShell ? 8.0 : 12.0,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              viewModel.search(val);
            },
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchOrgMembers,
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
        style: AppText.sm.copyWith(color: context.colors.textSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }

  bool _isDisabled(String userId) {
    return (widget.disabledUserIds?.contains(userId) ?? false) ||
        (widget.disabledCheckedUserIds?.contains(userId) ?? false);
  }

  bool _isChecked(String userId) {
    return _selectedUserIds.contains(userId) ||
        (widget.disabledCheckedUserIds?.contains(userId) ?? false);
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
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxSelectCount(widget.maxSelected));
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
    // 用 minTileHeight 而不是外层 Container(minHeight):后者只会把容器撑高,
    // ListTile 的内容仍按自身高度锚在顶部,导致行内不垂直居中。
    return ListTile(
      minTileHeight: LayoutScale.watchScale(context, baseHeight, cap: LayoutScale.rowCap),
      leading: Icon(
        Icons.corporate_fare,
        color: Theme.of(context).colorScheme.secondary,
        size: LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right,
        size: LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap),
      ),
      onTap: () => _viewModel.navigateToOrganization(subOrg),
    );
  }

  /// 部门行之间的分割线,左端与标题文字对齐(16 内边距 + 图标宽 + 16 标题间距)。
  Widget _buildTileDivider() {
    return Container(
      margin: EdgeInsets.only(
        left: 16.0 + LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap) + 16.0,
      ),
      height: 0.5,
      color: context.colors.hairlineSoft,
    );
  }

  Widget _buildEmployeeTile(Employee emp) {
    final isSelected = _isChecked(emp.employeeId);
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
        // 用 pushPage:桌面端在右栏 Navigator 里 push(组织架构还压在下面,可以返回),
        // 而不是把整个右栏换掉;移动端仍是整页 push。
        pushPage(context, UserInfoWidget(emp.employeeId));
      };
    }

    final hasSubtitle = emp.title != null && emp.title!.isNotEmpty;
    final baseHeight = hasSubtitle
        ? (isDesktopShell ? 64.0 : 72.0)
        : (isDesktopShell ? 48.0 : 56.0);

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: ListTile(
        minTileHeight: LayoutScale.watchScale(context, baseHeight, cap: LayoutScale.rowCap),
        leading: Portrait(
          emp.portraitUrl ?? WFPortraitProvider.instance.userDefaultPortrait(emp.toUserInfo()),
          Config.defaultUserPortrait,
        ),
        title: Text(emp.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: hasSubtitle ? Text(emp.title!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildOrganizationList(OrganizationViewModel viewModel) {
    final l10n = AppLocalizations.of(context)!;
    final details = viewModel.currentOrganizationDetails;
    if (details == null) {
      return Expanded(
        child: Center(child: Text(l10n.noOrganizationData)),
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
              l10n.orgNoSubOrgOrMembers,
              textAlign: TextAlign.center,
              style: AppText.base.copyWith(color: context.colors.textSecondary),
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
            _buildSectionHeader(l10n.subDepartments),
            for (int i = 0; i < subOrgs.length; i++) ...[
              if (i > 0) _buildTileDivider(),
              _buildSubOrgTile(subOrgs[i]),
            ],
          ],
          if (employees.isNotEmpty) ...[
            _buildSectionHeader(l10n.members),
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
            AppLocalizations.of(context)!.searchFailed(viewModel.searchError!),
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
            AppLocalizations.of(context)!.noMatchedMembers,
            style: AppText.base.copyWith(color: context.colors.textSecondary),
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
    final l10n = AppLocalizations.of(context)!;
    final label = _selectedUserIds.isEmpty
        ? l10n.confirm
        : l10n.confirmWithCount(_selectedUserIds.length, widget.maxSelected);
    return TextButton(
      onPressed: _onDone,
      // 栏标题右侧的确认位,比桌面按钮默认的 13 号大一号才压得住标题。
      style: isDesktopShell ? TextButton.styleFrom(textStyle: AppText.base) : null,
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
                  // 桌面端不要静态标题:面包屑说的就是"当前在哪个部门",跟标题是同一件事。
                  // 把面包屑放进标题栏,重复消掉,而三栏共用的 60px 水平线、返回键和
                  // 选人模式的「确定」都还留在原位。
                  // 不给返回键:层级内的后退由面包屑负责(点上级即回上级),再放一个返回键
                  // 是第二套后退语义,两者还会打架。返回键只在这一页是被 push 出来的时候
                  // 才出现(如从用户资料点部门进来),由 PcPageHeader 按导航栈自行判断。
                  ? PcPageHeader(
                      titleWidget: _buildBreadcrumbs(inHeader: true),
                      actions: widget.selectMode ? [_buildDoneAction()] : null,
                    )
                  // 移动端标题固定为「组织架构」:当前部门由正文里的面包屑交代,
                  // 标题跟着部门变会让人不知道自己还在不在组织架构里。
                  : AppBar(
                      title: Text(AppLocalizations.of(context)!.organization),
                      actions: widget.selectMode ? [_buildDoneAction()] : null,
                    ),
              backgroundColor: isDesktopShell ? context.colors.chatBgDesktop : null,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 移动端的面包屑仍是正文里的一条(标题栏归 AppBar);桌面端已经放进标题栏了。
                  if (!isDesktopShell) ...[
                    _buildBreadcrumbs(),
                    const Divider(height: 1),
                  ],
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
                              Text(viewModel.error!, textAlign: TextAlign.center, style: AppText.lg),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: Text(AppLocalizations.of(context)!.reload),
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
