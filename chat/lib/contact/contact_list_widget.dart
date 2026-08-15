import '../widgets/unread_badge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/ui_model/ui_contact_info.dart';
import 'package:chat/contact/friend_request_page.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/widget/prefix_extent_list.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';
import 'subscribed_channels.dart';
import '../mesh/domain_list_screen.dart';
import '../mesh/mesh_cache.dart';
import '../utils/layout_scale.dart';
import '../utils/external_target_utils.dart';
import '../utils/mesh_user_display.dart';
import '../utils/mesh_user_name.dart';
import '../utils/online_state_builder.dart';
import '../utils/online_state_formatter.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

// 行度量。子项 extent、A-Z 跳转偏移、侧栏字母表三者必须同源,
// 任何一边单独改写都会让 A-Z 跳转逐行累积偏差 —— 统一由 [_ContactListLayout] 产出。
const double _kRowHeight = 52.0;
const double _kCategoryHeight = 18.0;
const double _kDividerHeight = 0.5; // 不随字号缩放

/// 联系人列表的一次性布局计算结果。
///
/// 两万联系人时不能再用 `ListView.builder(itemExtentBuilder:)`:框架实现里
/// 每次求偏移/求可见下标都要从 0 逐项累加,单帧就是几十万次回调(详见
/// [ItemExtents] 的注释)。这里把每项高度、A-Z 偏移、侧栏字母表在数据变化时
/// 算一次,滚动期间的几何计算全部走前缀和。
class _ContactListLayout {
  const _ContactListLayout(this.extents, this.indexOffsets, this.indexList);

  /// 表头 + 联系人行的完整高度序列,长度等于列表 itemCount。
  final ItemExtents extents;

  /// 字母 -> 该分类第一行的滚动偏移。
  final Map<String, double> indexOffsets;

  /// 侧栏字母表。首项固定是回到顶部的 '↑'。
  final List<String> indexList;

  /// 固定表头行(新的朋友/收藏群组/…/组织)与联系人行共用同一个行高 [rowExtent],
  /// 联系人行带分类标题时再多一条 [categoryExtent] 高的纯文本分类条。
  factory _ContactListLayout.build({
    required List<UIContactInfo> contactList,
    required int headerCount,
    required double rowExtent,
    required double categoryExtent,
  }) {
    final itemExtents =
        List<double>.filled(headerCount + contactList.length, rowExtent);
    final indexOffsets = <String, double>{};
    final indexList = <String>['↑'];

    double offset = headerCount * rowExtent;
    for (int i = 0; i < contactList.length; i++) {
      final contact = contactList[i];
      final extent =
          contact.showCategory ? categoryExtent + rowExtent : rowExtent;
      itemExtents[headerCount + i] = extent;
      if (contact.showCategory) {
        var category = contact.category;
        if (category == '{') category = '#';
        if (!indexOffsets.containsKey(category)) {
          indexOffsets[category] = offset;
          // AI 机器人不进侧栏字母表
          if (!category.startsWith('AI')) {
            indexList.add(category);
          }
        }
      }
      offset += extent;
    }

    return _ContactListLayout(
        ItemExtents(itemExtents), indexOffsets, indexList);
  }
}

class ContactListWidget extends StatefulWidget {
  /// 桌面端 Shell 注入:点击联系人时回调(替代默认的全屏 push)。移动端不传,保持原有行为。
  final Function(String userId)? onUserSelected;

  const ContactListWidget({super.key, this.onUserSelected});

  @override
  State<ContactListWidget> createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  final ScrollController _scrollController = ScrollController();
  String _currentLetter = '';
  bool _isTouchingIndex = false;
  bool _meshEnabled = false;

  List<UIContactInfo>? _cachedContactList;
  int _cachedHeaderCount = 0;
  double _cachedFontScale = 1.0;
  _ContactListLayout? _cachedLayout;

  /// 布局只在「联系人列表实例 / 表头数量 / 字号」变化时重算。
  /// 上层 Selector2 每次 rebuild 都会走到这里,两万条的全量扫描不能每帧做。
  _ContactListLayout _layoutOf(
      List<UIContactInfo> contactList, int headerCount) {
    final fontScale = context.read<FontSizeViewModel>().textScaleFactor;
    final cached = _cachedLayout;
    if (cached != null &&
        identical(_cachedContactList, contactList) &&
        _cachedHeaderCount == headerCount &&
        _cachedFontScale == fontScale) {
      return cached;
    }

    final rowExtent =
        LayoutScale.scale(context, _kRowHeight, cap: LayoutScale.rowCap) +
            _kDividerHeight;
    final layout = _ContactListLayout.build(
      contactList: contactList,
      headerCount: headerCount,
      rowExtent: rowExtent,
      categoryExtent: LayoutScale.scale(context, _kCategoryHeight,
          cap: LayoutScale.textCap),
    );

    _cachedContactList = contactList;
    _cachedHeaderCount = headerCount;
    _cachedFontScale = fontScale;
    _cachedLayout = layout;
    return layout;
  }

  @override
  void initState() {
    super.initState();
    // 进入联系人列表时主动刷新一次，避免桌面端缺少事件回调导致空白。
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
      // 忽略错误，默认不显示
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 字号变化必须重跑本 build:itemExtentBuilder 与索引偏移都要按新字号重算。
    context.watch<FontSizeViewModel>();
    final List fixHeaderList = [
      [
        'assets/images/contact_new_friend.png',
        AppLocalizations.of(context)!.newFriend,
        'new_friend'
      ],
      [
        'assets/images/contact_fav_group.png',
        AppLocalizations.of(context)!.favGroup,
        'fav_group'
      ],
      [
        'assets/images/contact_subscribed_channel.png',
        AppLocalizations.of(context)!.subscribedChannel,
        'subscribed_channel'
      ],
      if (_meshEnabled) [null, AppLocalizations.of(context)!.mesh, 'mesh'],
    ];
    return ChangeNotifierProvider<OrganizationViewModel>(
      create: (_) {
        // Initialize OrganizationViewModel to handle organization-related logic
        var organizationViewModel = OrganizationViewModel();
        organizationViewModel.loadMyOrganizations();
        return organizationViewModel;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Selector2<
                  ContactListViewModel,
                  OrganizationViewModel,
                  ({
                    List<UIContactInfo> contactList,
                    int unreadFriendRequestCount,
                    List<Organization> rootOrgs,
                    List<Organization> myOrgs
                  })>(
                builder: (_, record, __) {
                  int headerCount = fixHeaderList.length +
                      record.rootOrgs.length +
                      record.myOrgs.length;
                  final layout = _layoutOf(record.contactList, headerCount);

                  return Stack(
                    children: [
                      CustomScrollView(
                        controller: _scrollController,
                        cacheExtent: 200,
                        slivers: [
                          SliverPrefixExtentList(
                            extents: layout.extents,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                if (i < fixHeaderList.length) {
                                  return _contactListFixHeader(
                                      context,
                                      i,
                                      record.unreadFriendRequestCount,
                                      fixHeaderList);
                                } else if (i <
                                    fixHeaderList.length +
                                        record.rootOrgs.length) {
                                  var org =
                                      record.rootOrgs[i - fixHeaderList.length];
                                  return _contactListOrgHeader(
                                      context, org, true);
                                } else if (i < headerCount) {
                                  var org = record.myOrgs[i -
                                      fixHeaderList.length -
                                      record.rootOrgs.length];
                                  return _contactListOrgHeader(
                                      context, org, false);
                                } else {
                                  var contactInfo =
                                      record.contactList[i - headerCount];
                                  return ContactListItem(
                                    contactInfo,
                                    key: ValueKey(
                                        'contact_${contactInfo.userInfo.userId}'),
                                    onTap: widget.onUserSelected,
                                  );
                                }
                              },
                              childCount: layout.extents.length,
                              addAutomaticKeepAlives: false,
                            ),
                          ),
                        ],
                      ),
                      if (layout.indexList.isNotEmpty)
                        SidebarIndex(
                          indexList: layout.indexList,
                          onIndexSelected: (tag) {
                            final offset =
                                tag == '↑' ? 0.0 : layout.indexOffsets[tag];
                            if (offset != null &&
                                _scrollController.hasClients) {
                              _scrollController.jumpTo(offset);
                            }
                          },
                          onTouch: (tag, isTouching) {
                            if (_currentLetter != tag ||
                                _isTouchingIndex != isTouching) {
                              setState(() {
                                _currentLetter = tag;
                                _isTouchingIndex = isTouching;
                              });
                            }
                          },
                        ),
                    ],
                  );
                },
                selector: (_, contactListViewModel, organizationViewModel) => (
                  contactList: contactListViewModel.contactList,
                  unreadFriendRequestCount:
                      contactListViewModel.unreadFriendRequestCount,
                  rootOrgs: organizationViewModel.rootOrganizations,
                  myOrgs: organizationViewModel.myOrganizations
                ),
              ),
              if (_isTouchingIndex)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _currentLetter == '↑'
                        ? const Icon(Icons.arrow_upward,
                            size: 40, color: Colors.white)
                        : Text(
                            _currentLetter,
                            style: AppText.xxxl.copyWith(color: Colors.white),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(String? imagePath) {
    final size =
        LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap);
    if (imagePath == null || imagePath.isEmpty) {
      // 外部单位/固定入口图标，与其他带色圆角背景的入口图标保持一致
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF3098F0),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Icon(Icons.domain, size: size * 0.5, color: Colors.white),
      );
    }
    return Image.asset(imagePath, width: size, height: size);
  }

  Widget _contactListFixHeader(BuildContext context, int index,
      int unreadFriendRequestCount, List<dynamic> fixHeaderList) {
    String? imagePath = fixHeaderList[index][0] as String?;
    String title = (fixHeaderList[index][1] as String?) ?? '';
    String key = (fixHeaderList[index][2] as String?) ?? '';
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: () {
          if (key == "new_friend") {
            var contactListViewModel =
                Provider.of<ContactListViewModel>(context, listen: false);
            contactListViewModel.clearUnreadFriendRequestStatus();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const FriendRequestPage()),
            );
          } else if (key == "fav_group") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavGroupsPage()),
            );
          } else if (key == "subscribed_channel") {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SubscribedChannelsPage()),
            );
          } else if (key == "mesh") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DomainListScreen()),
            );
          } else {
            Fluttertoast.showToast(
                msg: AppLocalizations.of(context)!.methodNotImpl);
            if (kDebugMode) {
              print("on tap item $index");
            }
          }
        },
        hoverColor: context.colors.hoverOverlay,
        child: Column(
          children: <Widget>[
            Container(
              height: LayoutScale.watchScale(context, _kRowHeight,
                  cap: LayoutScale.rowCap),
              margin: EdgeInsets.fromLTRB(
                  16.0, 0.0, AppShell.isDesktopStyle ? 0.0 : 32.0, 0.0),
              child: Row(
                children: <Widget>[
                  key == 'new_friend'
                      ? UnreadBadge(
                          count: unreadFriendRequestCount,
                          child: _buildHeaderIcon(imagePath))
                      : _buildHeaderIcon(imagePath),
                  Container(
                    margin: const EdgeInsets.only(left: 16),
                  ),
                  Expanded(
                      child: Text(
                    title,
                    style: AppText.lg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            Divider(
              indent: AppShell.isDesktopStyle
                  ? 12.0
                  : 16.0 +
                      LayoutScale.watchScale(context, 40.0,
                          cap: LayoutScale.iconCap) +
                      16.0,
              endIndent: 12.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactListOrgHeader(
      BuildContext context, Organization org, bool isRoot) {
    String imagePath = isRoot
        ? 'assets/images/contact_organization.png'
        : 'assets/images/contact_organization_expended.png';
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            // Directly navigate to OrganizationViewPage.
            // The ViewModel in OrganizationViewPage will handle loading the root/default organization.
            MaterialPageRoute(
                builder: (context) => OrganizationScreen(
                      initialOrganizationId: org.id,
                    )),
          );
        },
        hoverColor: context.colors.hoverOverlay,
        child: Column(
          children: <Widget>[
            Container(
              height: LayoutScale.watchScale(context, _kRowHeight,
                  cap: LayoutScale.rowCap),
              margin: EdgeInsets.fromLTRB(
                  16.0, 0.0, AppShell.isDesktopStyle ? 0.0 : 32.0, 0.0),
              child: Row(
                children: <Widget>[
                  Image.asset(imagePath,
                      width: LayoutScale.watchScale(context, 40.0,
                          cap: LayoutScale.iconCap),
                      height: LayoutScale.watchScale(context, 40.0,
                          cap: LayoutScale.iconCap)),
                  Container(
                    margin: const EdgeInsets.only(left: 16),
                  ),
                  Expanded(
                      child: Text(
                    org.name ?? '',
                    style: AppText.lg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            Divider(
              indent: AppShell.isDesktopStyle
                  ? 12.0
                  : 16.0 +
                      LayoutScale.watchScale(context, 40.0,
                          cap: LayoutScale.iconCap) +
                      16.0,
              endIndent: 12.0,
            ),
          ],
        ),
      ),
    );
  }
}

class ContactListItem extends StatefulWidget {
  final UIContactInfo contactInfo;
  final Function(String userId)? onTap;

  const ContactListItem(this.contactInfo, {super.key, this.onTap});

  @override
  State<ContactListItem> createState() => _ContactListItemState();
}

class _ContactListItemState extends State<ContactListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // 只有外部域用户的显示名依赖 MeshCache(域名称异步到达后要重绘)。
    // 内部用户挂上监听没有收益,却会让每次 MeshCache 变化重建全部可见行。
    if (!ExternalTargetUtils.isExternalTarget(
        widget.contactInfo.userInfo.userId)) {
      return _buildContent(context, widget.contactInfo.userInfo);
    }
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        return _buildContent(context, widget.contactInfo.userInfo);
      },
    );
  }

  Widget _buildContent(BuildContext context, UserInfo userInfo) {
    Color getBgColor() {
      if (!AppShell.isPointerInput) return Colors.transparent;
      final selectedId =
          Provider.of<PCShellViewModel>(context).selectedContactItemId;
      final isSelected =
          selectedId == 'user-${widget.contactInfo.userInfo.userId}';
      if (isSelected) return context.colors.cellSelected;
      if (_hovered) return context.colors.cellHover;
      return Colors.transparent;
    }

    Widget contactRow = Container(
      height:
          LayoutScale.watchScale(context, _kRowHeight, cap: LayoutScale.rowCap),
      padding: EdgeInsets.fromLTRB(
          16.0, 0.0, AppShell.isDesktopStyle ? 0.0 : 32.0, 0.0),
      child: Row(
        children: <Widget>[
          Portrait(
            widget.contactInfo.userInfo.portrait ?? Config.defaultUserPortrait,
            Config.defaultUserPortrait,
            width: 40,
            height: 40,
          ),
          Container(
            margin: const EdgeInsets.only(left: 16),
          ),
          Expanded(child: _buildNameWithOnlineStatus(context, userInfo)),
          if (!AppShell.isDesktopStyle) const SizedBox(width: 12),
        ],
      ),
    );

    if (AppShell.isPointerInput) {
      contactRow = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: contactRow,
      );
    }

    return RepaintBoundary(
      child: Column(
        // 分类条要铺满整行。原先靠 View.of(context) 取物理屏宽换算,
        // 在分屏/桌面窗口下是错的,而且每行都要读一次 View;交给 stretch 即可。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 分类标题
          if (widget.contactInfo.showCategory)
            Container(
              // 纯文本条:用 textCap 完整跟随字号,否则最大档位下分类字母会被裁掉。
              height: LayoutScale.watchScale(context, _kCategoryHeight,
                  cap: LayoutScale.textCap),
              color: context.colors.hairlineSoft,
              padding: EdgeInsets.only(
                  left: 16, right: AppShell.isDesktopStyle ? 16.0 : 32.0),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.contactInfo.category == '{'
                    ? '#'
                    : (widget.contactInfo.category == '☆'
                        ? AppLocalizations.of(context)!.favFriend
                        : (widget.contactInfo.category == 'AI'
                            ? AppLocalizations.of(context)!.aiRobot
                            : widget.contactInfo.category)),
                style: AppText.xs.copyWith(color: context.colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Material(
            color: getBgColor(),
            child: InkWell(
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!(widget.contactInfo.userInfo.userId);
                } else {
                  _toUserInfoPage(context);
                }
              },
              hoverColor: context.colors.hoverOverlay,
              child: contactRow,
            ),
          ),
          Divider(
            indent: AppShell.isDesktopStyle
                ? 12.0
                : 16.0 +
                    LayoutScale.watchScale(context, 40.0,
                        cap: LayoutScale.iconCap) +
                    16.0,
            endIndent: 12.0,
          ),
        ],
      ),
    );
  }

  Widget _buildNameWithOnlineStatus(BuildContext context, UserInfo userInfo) {
    if (ExternalTargetUtils.isExternalTarget(userInfo.userId)) {
      return MeshUserName(
        userInfo,
        style: AppText.lg,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return OnlineStateBuilder(
      userId: userInfo.userId,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final showIndicator = OnlineStateFormatter.showIndicator(state);
        final statusText = OnlineStateFormatter.contactStatusText(state, l10n);

        final nameSpan =
            MeshUserDisplay.getReadableNameSpan(userInfo, style: AppText.lg);
        final spans = List<InlineSpan>.from(nameSpan.children ?? [nameSpan]);
        if (statusText != null && statusText.isNotEmpty) {
          spans.add(TextSpan(
            text: '($statusText)',
            style: AppText.sm
                .copyWith(color: Theme.of(context).colorScheme.secondary),
          ));
        }
        if (showIndicator) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
            ),
          ));
        }

        return Text.rich(
          TextSpan(children: spans, style: nameSpan.style),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  _toUserInfoPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              UserInfoWidget(widget.contactInfo.userInfo.userId)),
    );
  }
}
