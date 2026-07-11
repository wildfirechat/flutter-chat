import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/group/group_info_screen.dart';
import 'package:chat/channel/channel_info_widget.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/ui_model/ui_contact_info.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/mesh/domain_profile_screen.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/utils/online_state_builder.dart';
import 'package:chat/utils/online_state_formatter.dart';
import 'package:imclient/model/domain_info.dart';

import 'package:chat/utils/layout_scale.dart';
import 'package:chat/theme/app_colors.dart';

// ---- 中栏统一行度量(禁止散落硬编码,与 pc_theme 同一约定) ----
// 分组头与子行的内容左缘对齐在 _kContentInset:分组头 = 14 边距 + 18 折叠箭头 + 4 间距。
// 折叠箭头与 _kContentInset 都不随字号缩放,这条等式才在所有档位下成立;
// 之后两边都是 _iconBox + _kIconGap,所以文字左缘始终一致。
const double _kSectionHeaderHeight = 48;
const double _kChildRowHeight = 52;
const double _kGroupLabelHeight = 30;
const double _kIconBox = 36; // 图标/头像统一 36x36
const double _kContentInset = 36; // 图标/头像左缘
const double _kIconGap = 10;

double _sectionHeaderHeight(BuildContext context) => LayoutScale.watchScale(context, _kSectionHeaderHeight, cap: LayoutScale.rowCap);
double _childRowHeight(BuildContext context) => LayoutScale.watchScale(context, _kChildRowHeight, cap: LayoutScale.rowCap);
double _groupLabelHeight(BuildContext context) => LayoutScale.watchScale(context, _kGroupLabelHeight, cap: LayoutScale.rowCap);

/// 图标/头像的实际占位。注意 [Portrait] 会自己缩放,所以传给它的是未缩放的
/// [_kIconBox],渲染结果恰好等于本函数的返回值 —— 不要再把本函数的结果传进去。
double _iconBox(BuildContext context) => LayoutScale.watchScale(context, _kIconBox, cap: LayoutScale.iconCap);

/// 桌面端联系人中栏(参照微信 PC):固定分类(新的朋友/收藏群组/订阅频道)+
/// 可折叠的「组织架构」「联系人」。联系人下按 星标 / AI 机器人 / 字母序 分组内联铺开。
/// 条目经 app_navigator 在右栏打开;所有行高、缩进、色值统一走本文件顶部常量与 [PcTheme]。
class PcContactList extends StatefulWidget {
  const PcContactList({super.key});

  @override
  State<PcContactList> createState() => _PcContactListState();
}

class _PcContactListState extends State<PcContactList> {
  void _openUser(String userId) {
    Provider.of<PCShellViewModel>(context, listen: false).selectContactItem('user-$userId');
    openPage(context, UserInfoWidget(userId, key: ValueKey('pc-user-$userId')));
  }

  bool _newFriendExpanded = false;
  bool _groupsExpanded = false;
  bool _channelsExpanded = false;
  // 「组织架构」默认展开(替代原先常驻的组织行)
  bool _orgExpanded = true;
  // 「联系人」(星标 / AI / 普通好友)默认展开
  bool _contactExpanded = true;
  bool _meshEnabled = false;
  bool _meshExpanded = false;

  List<FriendRequest>? _friendRequests;
  final Map<String, UserInfo> _requestUserInfos = {};
  List<String>? _favGroupIds;
  List<String>? _channelIds;
  List<DomainInfo>? _meshDomains;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactListViewModel>().refresh();
      _checkMeshEnabled();
    });
  }

  Future<void> _checkMeshEnabled() async {
    try {
      final enabled = await Imclient.isMeshEnabled();
      if (mounted) {
        setState(() => _meshEnabled = enabled);
      }
    } catch (_) {
      // 忽略
    }
  }

  void _toggleMesh() {
    setState(() => _meshExpanded = !_meshExpanded);
    if (_meshExpanded && _meshDomains == null) {
      Imclient.getRemoteDomains().then((domains) {
        MeshCache.instance.putDomains(domains);
        if (mounted) {
          setState(() => _meshDomains = domains);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _meshDomains = []);
        }
      });
    }
  }

  void _toggleNewFriend() {
    setState(() => _newFriendExpanded = !_newFriendExpanded);
    if (_newFriendExpanded) {
      context.read<ContactListViewModel>().clearUnreadFriendRequestStatus();
      _loadFriendRequests();
    }
  }

  void _loadFriendRequests() {
    Imclient.getIncommingFriendRequest().then((requests) async {
      final userInfos = requests.isEmpty ? <UserInfo>[] : await Imclient.getUserInfos(requests.map((r) => r.target).toList());
      if (!mounted) {
        return;
      }
      setState(() {
        for (var ui in userInfos) {
          _requestUserInfos[ui.userId] = ui;
        }
        _friendRequests = requests;
      });
    });
  }

  void _toggleGroups() {
    setState(() => _groupsExpanded = !_groupsExpanded);
    if (_groupsExpanded && _favGroupIds == null) {
      Imclient.getFavGroups().then((groupIds) {
        if (mounted) {
          setState(() => _favGroupIds = groupIds);
        }
      });
    }
  }

  void _toggleChannels() {
    setState(() => _channelsExpanded = !_channelsExpanded);
    if (_channelsExpanded && _channelIds == null) {
      Imclient.getRemoteListenedChannels((channelIds) {
        if (mounted) {
          setState(() => _channelIds = channelIds);
        }
      }, (errorCode) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<OrganizationViewModel>(
      create: (_) => OrganizationViewModel()..loadMyOrganizations(),
      child: Selector2<ContactListViewModel, OrganizationViewModel,
          ({List<UIContactInfo> contactList, int unreadFriendRequestCount, List<Organization> rootOrgs, List<Organization> myOrgs})>(
        selector: (_, contactListViewModel, organizationViewModel) => (
          contactList: contactListViewModel.contactList,
          unreadFriendRequestCount: contactListViewModel.unreadFriendRequestCount,
          rootOrgs: organizationViewModel.rootOrganizations,
          myOrgs: organizationViewModel.myOrganizations
        ),
        builder: (context, record, _) {
          final hasOrg = record.rootOrgs.isNotEmpty || record.myOrgs.isNotEmpty;
          return ListView(
            children: [
              _SectionHeader(
                iconAsset: 'assets/images/contact_new_friend.png',
                title: l10n.newFriend,
                expanded: _newFriendExpanded,
                badgeCount: record.unreadFriendRequestCount,
                onTap: _toggleNewFriend,
              ),
              if (_newFriendExpanded) ..._buildFriendRequestRows(context),
              _SectionHeader(
                iconAsset: 'assets/images/contact_fav_group.png',
                title: l10n.favGroup,
                expanded: _groupsExpanded,
                onTap: _toggleGroups,
              ),
              if (_groupsExpanded) ..._buildFavGroupRows(context),
              _SectionHeader(
                iconAsset: 'assets/images/contact_subscribed_channel.png',
                title: l10n.subscribedChannel,
                expanded: _channelsExpanded,
                onTap: _toggleChannels,
              ),
              if (_channelsExpanded) ..._buildChannelRows(context),
              // 「外部单位/Mesh」可折叠分组
              if (_meshEnabled) ...[
                _SectionHeader(
                  icon: Icons.domain,
                  title: l10n.mesh,
                  expanded: _meshExpanded,
                  onTap: _toggleMesh,
                ),
                if (_meshExpanded) ..._buildMeshRows(context),
              ],
              // 「组织架构」可折叠分组
              if (hasOrg) ...[
                _SectionHeader(
                  icon: Icons.account_tree_outlined,
                  title: l10n.organization,
                  expanded: _orgExpanded,
                  onTap: () => setState(() => _orgExpanded = !_orgExpanded),
                ),
                if (_orgExpanded) ...[
                  for (var org in record.rootOrgs) _buildOrgRow(context, org, true),
                  for (var org in record.myOrgs) _buildOrgRow(context, org, false),
                ],
              ],
              // 「联系人」可折叠分组:星标联系人 / AI 机器人 / 普通联系人(字母序)全部收入其下
              if (record.contactList.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.contacts_outlined,
                  title: l10n.contactCategory,
                  expanded: _contactExpanded,
                  onTap: () => setState(() => _contactExpanded = !_contactExpanded),
                ),
                if (_contactExpanded) ..._buildContactRows(context, record.contactList),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFriendRequestRows(BuildContext context) {
    final requests = _friendRequests;
    if (requests == null) {
      return [const _SectionLoadingRow()];
    }
    if (requests.isEmpty) {
      return [_SectionEmptyRow(text: AppLocalizations.of(context)!.noSearchResult)];
    }
    final selectedId = Provider.of<PCShellViewModel>(context).selectedContactItemId;
    return requests
        .map((request) => _FriendRequestRow(
              request: request,
              userInfo: _requestUserInfos[request.target],
              onTap: () => _openUser(request.target),
              onAccepted: _loadFriendRequests,
              isSelected: selectedId == 'user-${request.target}',
            ))
        .toList();
  }

  List<Widget> _buildFavGroupRows(BuildContext context) {
    final groupIds = _favGroupIds;
    if (groupIds == null) {
      return [const _SectionLoadingRow()];
    }
    final shell = Provider.of<PCShellViewModel>(context);
    final selectedId = shell.selectedContactItemId;
    return groupIds.map((groupId) {
      final itemId = 'group-$groupId';
      final isSelected = selectedId == itemId;
      return Consumer<GroupViewModel>(
        builder: (context, groupViewModel, _) {
          GroupInfo groupInfo = groupViewModel.getGroupInfo(groupId);
          return _EntryRow(
            portrait: groupInfo.portrait,
            defaultPortrait: Config.defaultGroupPortrait,
            title: groupInfo.name ?? groupId,
            isSelected: isSelected,
            onTap: () {
              shell.selectContactItem(itemId);
              openPage(context, GroupInfoScreen(groupId: groupId));
            },
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildChannelRows(BuildContext context) {
    final channelIds = _channelIds;
    if (channelIds == null) {
      return [const _SectionLoadingRow()];
    }
    final shell = Provider.of<PCShellViewModel>(context);
    final selectedId = shell.selectedContactItemId;
    return channelIds.map((channelId) {
      final itemId = 'channel-$channelId';
      final isSelected = selectedId == itemId;
      return Consumer<ChannelViewModel>(
        builder: (context, channelViewModel, _) {
          ChannelInfo? channelInfo = channelViewModel.getChannelInfo(channelId);
          return _EntryRow(
            portrait: channelInfo?.portrait,
            defaultPortrait: Config.defaultChannelPortrait,
            title: channelInfo?.name ?? channelId,
            isSelected: isSelected,
            onTap: () {
              shell.selectContactItem(itemId);
              openPage(context, ChannelInfoWidget(channelId: channelId, channelInfo: channelInfo));
            },
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildMeshRows(BuildContext context) {
    final domains = _meshDomains;
    if (domains == null) {
      return [const _SectionLoadingRow()];
    }
    final shell = Provider.of<PCShellViewModel>(context);
    final selectedId = shell.selectedContactItemId;
    return domains.map((domain) {
      final itemId = 'mesh-${domain.domainId}';
      final isSelected = selectedId == itemId;
      return _EntryRow(
        icon: Icons.domain,
        title: domain.name,
        isSelected: isSelected,
        onTap: () {
          shell.selectContactItem(itemId);
          openPage(context, DomainProfileScreen(domainId: domain.domainId));
        },
      );
    }).toList();
  }

  /// 「联系人」展开后的行:从 view model 的字母序 [contactList] 就地拆分为
  /// 星标(category '☆') / AI 机器人(category 'AI') / 普通好友(字母)三段,
  /// 各段前置一个分组小标题,成员用统一的 [_ContactRow] 渲染。
  List<Widget> _buildContactRows(BuildContext context, List<UIContactInfo> contactList) {
    final l10n = AppLocalizations.of(context)!;
    final fav = <UIContactInfo>[];
    final ai = <UIContactInfo>[];
    final regular = <UIContactInfo>[];
    for (final c in contactList) {
      if (c.category == '☆') {
        fav.add(c);
      } else if (c.category == 'AI') {
        ai.add(c);
      } else {
        regular.add(c);
      }
    }

    final rows = <Widget>[];
    if (fav.isNotEmpty) {
      rows.add(_GroupLabel(title: l10n.starredContact));
      for (final c in fav) {
        rows.add(_ContactRow(key: ValueKey('pc-fav-${c.userInfo.userId}'), userInfo: c.userInfo, onTap: () => _openUser(c.userInfo.userId)));
      }
    }
    if (ai.isNotEmpty) {
      rows.add(_GroupLabel(title: l10n.aiRobot));
      for (final c in ai) {
        rows.add(_ContactRow(key: ValueKey('pc-ai-${c.userInfo.userId}'), userInfo: c.userInfo, onTap: () => _openUser(c.userInfo.userId)));
      }
    }
    for (final c in regular) {
      // showCategory 由 view model 按字母边界预置;拆出星标/AI 后首个普通好友仍为 true。
      if (c.showCategory) {
        rows.add(_GroupLabel(title: c.category == '{' ? '#' : c.category));
      }
      rows.add(_ContactRow(key: ValueKey('pc-contact-${c.userInfo.userId}'), userInfo: c.userInfo, onTap: () => _openUser(c.userInfo.userId)));
    }
    return rows;
  }

  Widget _buildOrgRow(BuildContext context, Organization org, bool isRoot) {
    final shell = Provider.of<PCShellViewModel>(context);
    final itemId = 'org-${org.id}';
    final isSelected = shell.selectedContactItemId == itemId;
    return _EntryRow(
      assetIcon: isRoot ? 'assets/images/contact_organization.png' : 'assets/images/contact_organization_expended.png',
      title: org.name,
      isSelected: isSelected,
      onTap: () {
        shell.selectContactItem(itemId);
        openPage(context, OrganizationScreen(initialOrganizationId: org.id));
      },
    );
  }
}

/// 可折叠分组大标题:折叠箭头 + 图标(资源图或 IconData)+ 标题(+ 未读角标)。
/// 图标框 36x36,左缘落在 [_kContentInset],使标题与子行文字对齐同一列。
class _SectionHeader extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final String title;
  final bool expanded;
  final int badgeCount;
  final VoidCallback onTap;

  const _SectionHeader({
    this.iconAsset,
    this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.badgeCount = 0,
  }) : assert(iconAsset != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _sectionHeaderHeight(context),
          padding: const EdgeInsets.only(left: 14, right: 14),
          color: hovered ? context.colors.cellHover : Colors.transparent,
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.textTertiary,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: _iconBox(context),
                height: _iconBox(context),
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: LayoutScale.watchScale(context, 24), color: context.colors.accent)
                      : Image.asset(iconAsset!, width: LayoutScale.watchScale(context, 28), height: LayoutScale.watchScale(context, 28)),
                ),
              ),
              const SizedBox(width: _kIconGap),
              Expanded(child: Text(title, style: PcTheme.cellTitle(context))),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: context.colors.badge, borderRadius: BorderRadius.circular(9)),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组小标题(星标联系人 / AI 机器人 / 字母),薄条,高度统一,文字左缘与头像对齐。
class _GroupLabel extends StatelessWidget {
  final String title;

  const _GroupLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _groupLabelHeight(context),
      padding: const EdgeInsets.only(left: _kContentInset, right: 14),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(fontSize: 12, color: context.colors.textSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 分类展开后的条目行(群组/频道/组织):图标 + 标题,统一行高与缩进。
class _EntryRow extends StatelessWidget {
  final String? portrait;
  final String? defaultPortrait;
  final String? assetIcon;
  final IconData? icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;

  const _EntryRow({
    this.portrait,
    this.defaultPortrait,
    this.assetIcon,
    this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    Color getBgColor(bool hovered) {
      if (isSelected) return context.colors.cellSelectedDesktop;
      if (hovered) return context.colors.cellHover;
      return Colors.transparent;
    }

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _childRowHeight(context),
          padding: const EdgeInsets.only(left: _kContentInset, right: 14),
          color: getBgColor(hovered),
          child: Row(
            children: [
              if (assetIcon != null)
                SizedBox(width: _iconBox(context), height: _iconBox(context), child: Center(child: Image.asset(assetIcon!, width: LayoutScale.watchScale(context, 28), height: LayoutScale.watchScale(context, 28))))
              else if (icon != null)
                SizedBox(width: _iconBox(context), height: _iconBox(context), child: Center(child: Icon(icon, size: LayoutScale.watchScale(context, 28), color: context.colors.textSecondary)))
              else
                Portrait(portrait ?? defaultPortrait!, defaultPortrait!, width: _kIconBox, height: _kIconBox, borderRadius: 4),
              const SizedBox(width: _kIconGap),
              Expanded(child: Text(title, style: PcTheme.cellTitle(context).copyWith(color: isSelected ? Colors.white : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 联系人行(星标 / AI / 普通好友通用):头像 + 名称,支持悬停/选中态。
class _ContactRow extends StatelessWidget {
  final UserInfo userInfo;
  final VoidCallback onTap;

  const _ContactRow({super.key, required this.userInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        final selectedId = Provider.of<PCShellViewModel>(context).selectedContactItemId;
        final isSelected = selectedId == 'user-${userInfo.userId}';

        Color getBgColor(bool hovered) {
          if (isSelected) return context.colors.cellSelectedDesktop;
          if (hovered) return context.colors.cellHover;
          return Colors.transparent;
        }

        return HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: _childRowHeight(context),
              padding: const EdgeInsets.only(left: _kContentInset, right: 14),
              color: getBgColor(hovered),
              child: Row(
                children: [
                  Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: _kIconBox, height: _kIconBox, borderRadius: 4),
                  const SizedBox(width: _kIconGap),
                  Expanded(child: _buildName(context, isSelected)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildName(BuildContext context, bool isSelected) {
    if (ExternalTargetUtils.isExternalTarget(userInfo.userId)) {
      return MeshUserName(userInfo, style: PcTheme.cellTitle(context).copyWith(color: isSelected ? Colors.white : null), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return OnlineStateBuilder(
      userId: userInfo.userId,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final showIndicator = OnlineStateFormatter.showIndicator(state);
        final statusText = OnlineStateFormatter.contactStatusText(state, l10n);

        final nameSpan = MeshUserDisplay.getReadableNameSpan(userInfo);
        final spans = List<InlineSpan>.from(nameSpan.children ?? [nameSpan]);
        if (statusText != null && statusText.isNotEmpty) {
          spans.add(TextSpan(
            text: '($statusText)',
            style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : context.colors.textSecondary),
          ));
        }

        return Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: spans, style: nameSpan.style),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showIndicator)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  final FriendRequest request;
  final UserInfo? userInfo;
  final VoidCallback onTap;
  final VoidCallback onAccepted;
  final bool isSelected;

  const _FriendRequestRow({
    required this.request,
    this.userInfo,
    required this.onTap,
    required this.onAccepted,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        Color getBgColor(bool hovered) {
          if (isSelected) return context.colors.cellSelectedDesktop;
          if (hovered) return context.colors.cellHover;
          return Colors.transparent;
        }

        return HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: _childRowHeight(context),
              padding: const EdgeInsets.only(left: _kContentInset, right: 14),
              color: getBgColor(hovered),
              child: Row(
                children: [
                  Portrait(userInfo?.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: _kIconBox, height: _kIconBox, borderRadius: 4),
                  const SizedBox(width: _kIconGap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        userInfo != null
                            ? MeshUserName(
                                userInfo!,
                                style: PcTheme.cellTitle(context).copyWith(color: isSelected ? Colors.white : null),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                '<${request.target}>',
                                style: PcTheme.cellTitle(context).copyWith(color: isSelected ? Colors.white : null),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        if (request.reason != null && request.reason!.isNotEmpty)
                          Text(request.reason!, style: PcTheme.cellSubtitle(context).copyWith(color: isSelected ? Colors.white : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTrailing(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (request.status == FriendRequestStatus.WaitingAccept) {
      return SizedBox(
        height: 24,
        child: OutlinedButton(
          onPressed: () {
            Imclient.handleFriendRequest(request.target, true, "", onAccepted, (errorCode) {});
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: isSelected ? Colors.white : context.colors.accent,
            side: BorderSide(color: isSelected ? Colors.white : context.colors.accent, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(AppLocalizations.of(context)!.friendRequestAccept),
        ),
      );
    }
    return Text(
      request.status == FriendRequestStatus.Accepted
          ? AppLocalizations.of(context)!.friendRequestAccepted
          : AppLocalizations.of(context)!.friendRequestRejected,
      style: PcTheme.cellSubtitle(context).copyWith(color: isSelected ? Colors.white : null),
    );
  }
}

class _SectionLoadingRow extends StatelessWidget {
  const _SectionLoadingRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _childRowHeight(context),
      child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

class _SectionEmptyRow extends StatelessWidget {
  final String text;

  const _SectionEmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _childRowHeight(context),
      child: Center(child: Text(text, style: PcTheme.cellSubtitle(context))),
    );
  }
}
