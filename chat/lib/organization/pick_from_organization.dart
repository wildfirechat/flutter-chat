import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';

import 'package:chat/app_shell.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';

/// push 组织架构选人页,把返回的完整已选写回 [viewModel]。
///
/// 组织架构页编辑的是同一份已选:已选的人会带进去,在里面取消勾选同样生效,上限按总数算;
/// 不可选 / 预置已选沿用 [viewModel] 的配置。直接返回(没点确定)则不改动。
///
/// 桌面端多选弹窗不走这里,而是在左栏原地浏览,见 `PcOrganizationPickColumn`。
Future<void> pickUsersFromOrganization(
    BuildContext context, PickUserViewModel viewModel) async {
  final result = await Navigator.push<List<UserInfo>>(
    context,
    MaterialPageRoute(
      builder: (_) => OrganizationScreen(
        selectMode: true,
        maxSelected: viewModel.maxPickCount,
        initialSelectedUsers: List.of(viewModel.pickedUsers),
        disabledUserIds: viewModel.uncheckableUserIds,
        disabledCheckedUserIds: viewModel.disabledAndCheckedUserIds,
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  viewModel.setPickedUsers(result);
}

/// 选人页顶部的「从组织架构选择」入口行(含下方分割线)。
class OrganizationPickEntry extends StatelessWidget {
  final VoidCallback onTap;

  const OrganizationPickEntry({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double iconSize =
        LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 用 minTileHeight 而不是外层 Container(minHeight):后者只会把容器撑高,
        // ListTile 的内容仍按自身高度锚在顶部,导致行内不垂直居中。
        ListTile(
          minTileHeight:
              LayoutScale.watchScale(context, 56.0, cap: LayoutScale.rowCap),
          leading: Icon(
            Icons.corporate_fare,
            color: Theme.of(context).colorScheme.secondary,
            size: iconSize,
          ),
          title: Text(AppLocalizations.of(context)!.selectFromOrganization),
          trailing: Icon(
            Icons.chevron_right,
            size:
                LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap),
          ),
          onTap: onTap,
        ),
        Divider(
          indent: AppShell.isDesktopStyle ? 16.0 : 16.0 + iconSize + 16.0,
        ),
      ],
    );
  }
}
