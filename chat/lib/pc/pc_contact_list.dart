import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/contact_list_widget.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/ui_model/ui_contact_info.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端联系人中栏(参照微信 PC):可折叠分类(新的朋友/收藏群组/订阅频道/组织)
/// 默认收起,点击展开;条目在右栏打开。字母序联系人列表复用 [ContactListItem]。
class PcContactList extends StatefulWidget {
  final void Function(String userId) onUserSelected;
  final void Function(Conversation conversation) onConversationSelected;
  final void Function(Widget page) onOpenPage;

  const PcContactList({
    super.key,
    required this.onUserSelected,
    required this.onConversationSelected,
    required this.onOpenPage,
  });

  @override
  State<PcContactList> createState() => _PcContactListState();
}

class _PcContactListState extends State<PcContactList> {
  bool _newFriendExpanded = false;
  bool _groupsExpanded = false;
  bool _channelsExpanded = false;

  List<FriendRequest>? _friendRequests;
  final Map<String, UserInfo> _requestUserInfos = {};
  List<String>? _favGroupIds;
  List<String>? _channelIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactListViewModel>().refresh();
    });
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
              for (var org in record.rootOrgs) _buildOrgRow(context, org, true),
              for (var org in record.myOrgs) _buildOrgRow(context, org, false),
              const SizedBox(height: 4),
              // key 必须带序号:星标/AI 分类会让同一用户在列表中出现两次,
              // 仅用 userId 做 key 会在 children 更新时触发 Duplicate keys 异常(整个列表变 ErrorBox)
              for (var i = 0; i < record.contactList.length; i++)
                ContactListItem(
                  record.contactList[i],
                  key: ValueKey('pc-contact-$i-${record.contactList[i].userInfo.userId}'),
                  onTap: widget.onUserSelected,
                ),
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
    return requests
        .map((request) => _FriendRequestRow(
              request: request,
              userInfo: _requestUserInfos[request.target],
              onTap: () => widget.onUserSelected(request.target),
              onAccepted: _loadFriendRequests,
            ))
        .toList();
  }

  List<Widget> _buildFavGroupRows(BuildContext context) {
    final groupIds = _favGroupIds;
    if (groupIds == null) {
      return [const _SectionLoadingRow()];
    }
    return groupIds.map((groupId) {
      return Consumer<GroupViewModel>(
        builder: (context, groupViewModel, _) {
          GroupInfo groupInfo = groupViewModel.getGroupInfo(groupId);
          return _EntryRow(
            portrait: groupInfo.portrait,
            defaultPortrait: Config.defaultGroupPortrait,
            title: groupInfo.name ?? groupId,
            onTap: () => widget.onConversationSelected(Conversation(conversationType: ConversationType.Group, target: groupId, line: 0)),
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
    return channelIds.map((channelId) {
      return Consumer<ChannelViewModel>(
        builder: (context, channelViewModel, _) {
          ChannelInfo? channelInfo = channelViewModel.getChannelInfo(channelId);
          return _EntryRow(
            portrait: channelInfo?.portrait,
            defaultPortrait: Config.defaultChannelPortrait,
            title: channelInfo?.name ?? channelId,
            onTap: () => widget.onConversationSelected(Conversation(conversationType: ConversationType.Channel, target: channelId, line: 0)),
          );
        },
      );
    }).toList();
  }

  Widget _buildOrgRow(BuildContext context, Organization org, bool isRoot) {
    return _EntryRow(
      assetIcon: isRoot ? 'assets/images/contact_organization.png' : 'assets/images/contact_organization_expended.png',
      title: org.name,
      onTap: () => widget.onOpenPage(OrganizationScreen(initialOrganizationId: org.id)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String iconAsset;
  final String title;
  final bool expanded;
  final int badgeCount;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.iconAsset,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: hovered ? PcTheme.cellHover : Colors.transparent,
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                size: 18,
                color: PcTheme.textTertiary,
              ),
              const SizedBox(width: 4),
              Image.asset(iconAsset, width: 28, height: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: PcTheme.cellTitle)),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: PcTheme.badgeRed, borderRadius: BorderRadius.circular(9)),
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

/// 分类展开后的条目行(群组/频道/组织)。
class _EntryRow extends StatelessWidget {
  final String? portrait;
  final String? defaultPortrait;
  final String? assetIcon;
  final String title;
  final VoidCallback onTap;

  const _EntryRow({this.portrait, this.defaultPortrait, this.assetIcon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 36, right: 14),
          color: hovered ? PcTheme.cellHover : Colors.transparent,
          child: Row(
            children: [
              if (assetIcon != null)
                Image.asset(assetIcon!, width: 28, height: 28)
              else
                Portrait(portrait ?? defaultPortrait!, defaultPortrait!, width: 28, height: 28, borderRadius: 4),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: PcTheme.cellTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  final FriendRequest request;
  final UserInfo? userInfo;
  final VoidCallback onTap;
  final VoidCallback onAccepted;

  const _FriendRequestRow({required this.request, this.userInfo, required this.onTap, required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 36, right: 14),
          color: hovered ? PcTheme.cellHover : Colors.transparent,
          child: Row(
            children: [
              Portrait(userInfo?.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 32, height: 32, borderRadius: 4),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userInfo?.getReadableName() ?? '<${request.target}>',
                        style: PcTheme.cellTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (request.reason != null && request.reason!.isNotEmpty)
                      Text(request.reason!, style: PcTheme.cellSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            foregroundColor: PcTheme.accent,
            side: const BorderSide(color: PcTheme.accent, width: 1),
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
      style: PcTheme.cellSubtitle,
    );
  }
}

class _SectionLoadingRow extends StatelessWidget {
  const _SectionLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

class _SectionEmptyRow extends StatelessWidget {
  final String text;

  const _SectionEmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(child: Text(text, style: PcTheme.cellSubtitle)),
    );
  }
}
