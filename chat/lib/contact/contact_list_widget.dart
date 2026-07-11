import 'package:badges/badges.dart' as badge;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/ui_model/ui_contact_info.dart';
import 'package:chat/contact/friend_request_page.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';
import 'subscribed_channels.dart';
import '../mesh/domain_list_screen.dart';
import '../mesh/mesh_cache.dart';
import '../pc/pc_platform.dart';
import '../utils/layout_scale.dart';
import '../utils/mesh_user_display.dart';
import 'package:chat/theme/app_colors.dart';

// 行度量。itemExtentBuilder 与侧栏索引的跳转偏移必须共用下面两个函数,
// 任何一边单独改写都会让 A-Z 跳转逐行累积偏差。
const double _kRowHeight = 52.0;
const double _kCategoryHeight = 18.0;
const double _kDividerHeight = 0.5; // 不随字号缩放

/// 固定表头行(新的朋友/收藏群组/…/组织)的完整高度。
double _headerExtent(BuildContext context) =>
    LayoutScale.scale(context, _kRowHeight, cap: LayoutScale.rowCap) + _kDividerHeight;

/// 联系人行的完整高度。带分类标题时多一条纯文本的分类条。
double _contactExtent(BuildContext context, bool showCategory) =>
    (showCategory ? LayoutScale.scale(context, _kCategoryHeight, cap: LayoutScale.textCap) : 0) +
    LayoutScale.scale(context, _kRowHeight, cap: LayoutScale.rowCap) +
    _kDividerHeight;

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
  Map<String, double> _cachedOffsets = {};

  Map<String, double> _getOffsets(List<UIContactInfo> contactList, int headerCount) {
    final fontScale = context.read<FontSizeViewModel>().textScaleFactor;
    if (_cachedContactList == contactList && _cachedHeaderCount == headerCount && _cachedFontScale == fontScale) {
      return _cachedOffsets;
    }
    _cachedContactList = contactList;
    _cachedHeaderCount = headerCount;
    _cachedFontScale = fontScale;
    _cachedOffsets = _calculateIndexOffsets(contactList, headerCount);
    return _cachedOffsets;
  }

  Map<String, double> _calculateIndexOffsets(List<UIContactInfo> contactList, int headerCount) {
    Map<String, double> offsets = {};
    double offset = headerCount * _headerExtent(context);
    for (var contact in contactList) {
      if (contact.showCategory) {
        String category = contact.category;
        if (category == '{') category = '#';
        if (!offsets.containsKey(category)) {
          offsets[category] = offset;
        }
      }
      offset += _contactExtent(context, contact.showCategory);
    }
    return offsets;
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
      ['assets/images/contact_new_friend.png', AppLocalizations.of(context)!.newFriend, 'new_friend'],
      ['assets/images/contact_fav_group.png', AppLocalizations.of(context)!.favGroup, 'fav_group'],
      ['assets/images/contact_subscribed_channel.png', AppLocalizations.of(context)!.subscribedChannel, 'subscribed_channel'],
      if (_meshEnabled)
        [null, AppLocalizations.of(context)!.mesh, 'mesh'],
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
              Selector2<ContactListViewModel, OrganizationViewModel,
                  ({List<UIContactInfo> contactList, int unreadFriendRequestCount, List<Organization> rootOrgs, List<Organization> myOrgs})>(
                builder: (_, record, __) {
                  List<String> indexList = _getIndexList(record.contactList);
                  int headerCount = fixHeaderList.length + record.rootOrgs.length + record.myOrgs.length;
                  Map<String, double> indexOffsets = _getOffsets(record.contactList, headerCount);

                  return Stack(
                    children: [
                      ListView.builder(
                          controller: _scrollController,
                          itemCount: headerCount + record.contactList.length,
                          // 使用key帮助ListView正确处理数据更新
                          key: ValueKey('contact_list_${record.contactList.length}'),
                          cacheExtent: 200,
                          addRepaintBoundaries: true,
                          addAutomaticKeepAlives: false,
                          // 字号变化时 build 重跑,新的闭包会让 RenderSliverVariedExtentList
                          // 重新 layout;这里必须用不注册依赖的 LayoutScale.scale。
                          itemExtentBuilder: (index, dimensions) {
                            if (index < headerCount) {
                              return _headerExtent(context);
                            }
                            return _contactExtent(context, record.contactList[index - headerCount].showCategory);
                          },
                          itemBuilder: (context, i) {
                            if (i < fixHeaderList.length) {
                              return _contactListFixHeader(context, i, record.unreadFriendRequestCount, fixHeaderList);
                            } else if (i < fixHeaderList.length + record.rootOrgs.length) {
                              var org = record.rootOrgs[i - fixHeaderList.length];
                              return _contactListOrgHeader(context, org, true);
                            } else if (i < headerCount) {
                              var org = record.myOrgs[i - fixHeaderList.length - record.rootOrgs.length];
                              return _contactListOrgHeader(context, org, false);
                            } else {
                              var contactInfo = record.contactList[i - headerCount];
                              return ContactListItem(
                                contactInfo,
                                key: ValueKey('contact_${contactInfo.userInfo.userId}-${contactInfo.userInfo.updateDt}'),
                                onTap: widget.onUserSelected,
                              );
                            }
                          }),
                      if (indexList.isNotEmpty)
                        SidebarIndex(
                          indexList: indexList,
                          onIndexSelected: (tag) {
                            final offset = tag == '↑' ? 0.0 : indexOffsets[tag];
                            if (offset != null && _scrollController.hasClients) {
                              _scrollController.jumpTo(offset);
                            }
                          },
                          onTouch: (tag, isTouching) {
                            if (_currentLetter != tag || _isTouchingIndex != isTouching) {
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
                  unreadFriendRequestCount: contactListViewModel.unreadFriendRequestCount,
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
                        ? const Icon(Icons.arrow_upward, size: 40, color: Colors.white)
                        : Text(
                            _currentLetter,
                            style: const TextStyle(color: Colors.white, fontSize: 40),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getIndexList(List<UIContactInfo> contactList) {
    List<String> indexList = [];
    indexList.add('↑');
    for (var contact in contactList) {
      if (contact.showCategory) {
        String category = contact.category;
        if (category.startsWith("AI")) continue;
        if (category == "{") category = "#";
        if (!indexList.contains(category)) {
          indexList.add(category);
        }
      }
    }
    return indexList;
  }

  Widget _buildHeaderIcon(String? imagePath) {
    final size = LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap);
    if (imagePath == null || imagePath.isEmpty) {
      return Icon(Icons.domain, size: size);
    }
    return Image.asset(imagePath, width: size, height: size);
  }

  Widget _contactListFixHeader(BuildContext context, int index, int unreadFriendRequestCount, List<dynamic> fixHeaderList) {
    String? imagePath = fixHeaderList[index][0];
    String title = fixHeaderList[index][1];
    String key = fixHeaderList[index][2];
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: () {
          if (key == "new_friend") {
            var contactListViewModel = Provider.of<ContactListViewModel>(context, listen: false);
            contactListViewModel.clearUnreadFriendRequestStatus();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendRequestPage()),
            );
          } else if (key == "fav_group") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavGroupsPage()),
            );
          } else if (key == "subscribed_channel") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubscribedChannelsPage()),
            );
          } else if (key == "mesh") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DomainListScreen()),
            );
          } else {
            Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
            if (kDebugMode) {
              print("on tap item $index");
            }
          }
        },
        hoverColor: context.colors.hoverOverlay,
        child: Column(
          children: <Widget>[
            Container(
              height: LayoutScale.watchScale(context, _kRowHeight, cap: LayoutScale.rowCap),
              margin: EdgeInsets.fromLTRB(16.0, 0.0, isDesktopShell ? 0.0 : 32.0, 0.0),
              child: Row(
                children: <Widget>[
                  key == 'new_friend'
                      ? badge.Badge(
                          showBadge: unreadFriendRequestCount > 0,
                          badgeContent: Text(
                            unreadFriendRequestCount > 99 ? '99+' : '$unreadFriendRequestCount',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          badgeStyle: badge.BadgeStyle(
                            badgeColor: context.colors.badge,
                            padding: isDesktopShell ? const EdgeInsets.all(5) : const EdgeInsets.all(4),
                          ),
                          child: _buildHeaderIcon(imagePath))
                      : _buildHeaderIcon(imagePath),
                  Container(
                    margin: const EdgeInsets.only(left: 16),
                  ),
                  Expanded(
                      child: Text(
                    title,
                    style: const TextStyle(fontSize: 15.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                isDesktopShell
                    ? 12.0
                    : 16.0 + LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) + 16.0,
                0.0,
                12.0,
                0.0,
              ),
              height: _kDividerHeight,
              color: context.colors.hairlineSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactListOrgHeader(BuildContext context, Organization org, bool isRoot) {
    String imagePath = isRoot ? 'assets/images/contact_organization.png' : 'assets/images/contact_organization_expended.png';
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
              height: LayoutScale.watchScale(context, _kRowHeight, cap: LayoutScale.rowCap),
              margin: EdgeInsets.fromLTRB(16.0, 0.0, isDesktopShell ? 0.0 : 32.0, 0.0),
              child: Row(
                children: <Widget>[
                  Image.asset(imagePath, width: LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap), height: LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap)),
                  Container(
                    margin: const EdgeInsets.only(left: 16),
                  ),
                  Expanded(
                      child: Text(
                    org.name ?? '',
                    style: const TextStyle(fontSize: 15.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                isDesktopShell
                    ? 12.0
                    : 16.0 + LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) + 16.0,
                0.0,
                12.0,
                0.0,
              ),
              height: _kDividerHeight,
              color: context.colors.hairlineSoft,
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
    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        // 获取显示名称（含外部单位后缀）
        final displayName = MeshUserDisplay.getReadableName(widget.contactInfo.userInfo);
        return _buildContent(context, displayName);
      },
    );
  }

  Widget _buildContent(BuildContext context, String displayName) {
    Color getBgColor() {
      if (!isDesktopShell) return Colors.transparent;
      final selectedId = Provider.of<PCShellViewModel>(context).selectedContactItemId;
      final isSelected = selectedId == 'user-${widget.contactInfo.userInfo.userId}';
      if (isSelected) return context.colors.cellSelected;
      if (_hovered) return context.colors.cellHover;
      return Colors.transparent;
    }

    Widget contactRow = Container(
      height: LayoutScale.watchScale(context, _kRowHeight, cap: LayoutScale.rowCap),
      padding: EdgeInsets.fromLTRB(16.0, 0.0, isDesktopShell ? 0.0 : 32.0, 0.0),
      child: Row(
        children: <Widget>[
          Portrait(widget.contactInfo.userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 40, height: 40,),
          Container(
            margin: const EdgeInsets.only(left: 16),
          ),
          Expanded(
              child: Text(
            displayName,
            style: const TextStyle(fontSize: 15.0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
        ],
      ),
    );

    if (isDesktopShell) {
      contactRow = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: contactRow,
      );
    }

    return RepaintBoundary(
      child: Column(
        children: <Widget>[
          // 分类标题
          if (widget.contactInfo.showCategory)
            Container(
              // 纯文本条:用 textCap 完整跟随字号,否则最大档位下分类字母会被裁掉。
              height: LayoutScale.watchScale(context, _kCategoryHeight, cap: LayoutScale.textCap),
              width: View.of(context).physicalSize.width / View.of(context).devicePixelRatio,
              color: context.colors.hairlineSoft,
              padding: EdgeInsets.only(left: 16, right: isDesktopShell ? 16.0 : 32.0),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.contactInfo.category == '{'
                    ? '#'
                    : (widget.contactInfo.category == '☆'
                        ? AppLocalizations.of(context)!.favFriend
                        : (widget.contactInfo.category == 'AI' ? AppLocalizations.of(context)!.aiRobot : widget.contactInfo.category)),
                style: TextStyle(fontSize: 12.0, color: context.colors.textSecondary),
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
          Container(
            margin: EdgeInsets.fromLTRB(
              isDesktopShell
                  ? 12.0
                  : 16.0 + LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) + 16.0,
              0.0,
              12.0,
              0.0,
            ),
            height: _kDividerHeight,
            color: context.colors.hairlineSoft,
          ),
        ],
      ),
    );
  }

  _toUserInfoPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(widget.contactInfo.userInfo.userId)),
    );
  }
}
