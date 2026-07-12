import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/contact/invite_friend.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/section_divider.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/layout_scale.dart';

import 'package:chat/event_bus.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/model/organization_relationship.dart';
import 'package:chat/organization/organization_cache.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/organization/organization_service.dart';

import 'package:chat/pc/widgets/pc_page_header.dart';

import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/theme/app_typography.dart';

class UserInfoWidget extends StatefulWidget {
  const UserInfoWidget(this.userId, {this.inGroupId, super.key});
  final String userId;
  final String? inGroupId;

  @override
  State<UserInfoWidget> createState() => _UserInfoWidgetState();
}

class _UserInfoWidgetState extends State<UserInfoWidget> {
  bool _isBlacklisted = false;
  bool _isStarred = false;

  List<OrganizationRelationship> _bottomRelationships = [];
  final Map<int, Organization> _bottomOrganizations = {};
  bool _loadingOrg = true;
  StreamSubscription? _employeeExSub;
  StreamSubscription? _orgUpdateSub;

  /// 发起单聊:桌面 Shell 内交给 PCShellViewModel 在右栏打开并同步选中态,
  /// 移动端(无该 Provider)保持整页 push。
  void _openSingleConversation(BuildContext context) {
    openConversation(context, Conversation(conversationType: ConversationType.Single, target: widget.userId));
  }

  @override
  void initState() {
    super.initState();
    _employeeExSub = eventBus.on<EmployeeExUpdatedEvent>().listen((event) {
      if (event.employeeId == widget.userId) {
        _loadOrganizationInfo();
      }
    });
    _orgUpdateSub = eventBus.on<OrganizationUpdatedEvent>().listen((event) {
      if (_bottomOrganizations.containsKey(event.organizationId)) {
        _loadOrganizationInfo();
      }
    });
    _refreshUserInfo();
    _checkRelation();
    _loadOrganizationInfo(refresh: true);
  }

  @override
  void dispose() {
    _employeeExSub?.cancel();
    _orgUpdateSub?.cancel();
    super.dispose();
  }

  /// [refresh] 仅在首次加载时为 true；事件回调里必须只读缓存，
  /// 否则 refresh 拉取完成后 fire 的 EmployeeExUpdatedEvent 会再次触发
  /// 本方法，形成无限请求环。
  Future<void> _loadOrganizationInfo({bool refresh = false}) async {
    if (!OrganizationService.instance.isServiceAvailable()) {
      if (mounted) {
        setState(() {
          _loadingOrg = false;
        });
      }
      return;
    }

    final ex = OrganizationCache.instance.getEmployeeEx(widget.userId, refresh: refresh);
    final relationships = ex?.relationships ?? [];
    final bottomRels = relationships.where((r) => r.bottom).toList();
    final Map<int, Organization> orgs = {};
    for (final rel in bottomRels) {
      final org = OrganizationCache.instance.getOrganization(rel.organizationId, refresh: false);
      if (org != null) {
        orgs[rel.organizationId] = org;
      }
    }

    if (mounted) {
      setState(() {
        _bottomRelationships = bottomRels;
        _bottomOrganizations.clear();
        _bottomOrganizations.addAll(orgs);
        _loadingOrg = false;
      });
    }
  }

  void _openOrganization(int organizationId) {
    pushPage(
      context,
      OrganizationScreen(
        initialOrganizationId: organizationId,
        showBackOnRoot: true,
      ),
    );
  }

  Future<void> _refreshUserInfo() async {
    await Imclient.getUserInfo(widget.userId, refresh: true);
  }

  void _checkRelation() async {
    bool isBlacklisted = await Imclient.isBlackListed(widget.userId);
    bool isStarred = await Imclient.isFavUser(widget.userId);
    if (mounted) {
      setState(() {
        _isBlacklisted = isBlacklisted;
        _isStarred = isStarred;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final FutureBuilder<bool> actionsBuilder = FutureBuilder<bool>(
      future: _isFriend(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        bool isFriend = snapshot.data!;
        bool isMe = widget.userId == Imclient.currentUserId;
        if (isMe) return Container();

        return PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(value, isFriend),
          itemBuilder: (BuildContext context) {
            List<PopupMenuEntry<String>> items = [];
            if (isFriend) {
              items.add(PopupMenuItem(
                value: 'blacklist',
                child: Text(_isBlacklisted ? AppLocalizations.of(context)!.removeFromBlacklist : AppLocalizations.of(context)!.addToBlacklist),
              ));
              items.add(PopupMenuItem(
                value: 'star',
                child: Text(_isStarred ? AppLocalizations.of(context)!.cancelStarredFriend : AppLocalizations.of(context)!.setStarredFriend),
              ));
              items.add(PopupMenuItem(
                value: 'delete',
                child: Text(AppLocalizations.of(context)!.deleteFriend),
              ));
            } else {
              items.add(PopupMenuItem(
                value: 'blacklist',
                child: Text(_isBlacklisted ? AppLocalizations.of(context)!.removeFromBlacklist : AppLocalizations.of(context)!.addToBlacklist),
              ));
              items.add(PopupMenuItem(
                value: 'add_friend',
                child: Text(AppLocalizations.of(context)!.addFriend),
              ));
            }
            return items;
          },
        );
      },
    );

    return Scaffold(
      // 桌面端整页一张白底,分组之间只由 SectionDivider 的弱线交代;移动端仍是白卡片 + 凹槽灰。
      backgroundColor: isDesktopShell ? context.colors.surface : context.colors.primaryBackground,
      appBar: isDesktopShell
          ? PcPageHeader(
              title: AppLocalizations.of(context)!.userInfo,
              actions: [actionsBuilder],
            )
          : AppBar(
              title: Text(AppLocalizations.of(context)!.userInfo),
              actions: [actionsBuilder],
            ),
      body: SafeArea(
        child: Selector<UserViewModel, UserInfo?>(
          selector: (context, viewModel) => viewModel.getUserInfo(widget.userId, groupId: widget.inGroupId),
          builder: (context, userInfo, child) {
            return FutureBuilder<bool>(
              future: _isFriend(widget.userId),
              builder: (context, snapshot) {
                if (userInfo == null || !snapshot.hasData) {
                  return Center(child: Text(AppLocalizations.of(context)!.loading));
                }
                bool isFriend = snapshot.data!;
                bool isMe = widget.userId == Imclient.currentUserId;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        color: context.colors.surface,
                        child: _buildHeader(context, userInfo, isFriend),
                      ),
                      if (!_loadingOrg && _bottomRelationships.isNotEmpty) ...[
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: _buildOrganizationSection(),
                        ),
                      ],
                      if (isMe) ...[
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: Column(
                            children: [
                              OptionItem(AppLocalizations.of(context)!.modifyAlias, onTap: () {
                                _showSetDisplayNameDialog(context, userInfo);
                              }),
                              OptionItem(AppLocalizations.of(context)!.moreInfo, showBottomDivider: false, onTap: () {
                                Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                              }),
                            ],
                          ),
                        ),
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: OptionButtonItem(AppLocalizations.of(context)!.sendMsg, () {
                            _openSingleConversation(context);
                          }, showBottomDivider: false),
                        ),
                      ] else if (isFriend) ...[
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: Column(
                            children: [
                              OptionItem(AppLocalizations.of(context)!.setAlias, onTap: () {
                                _showSetAliasDialog(context, userInfo);
                              }),
                              OptionItem(AppLocalizations.of(context)!.moreInfo, showBottomDivider: false, onTap: () {
                                Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                              }),
                            ],
                          ),
                        ),
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: Column(
                            children: [
                              OptionButtonItem(AppLocalizations.of(context)!.sendMsg, () {
                                _openSingleConversation(context);
                              }, showBottomDivider: true),
                              OptionButtonItem('视频聊天', () {
                                // SingleVideoCallView callView = SingleVideoCallView(userId: userId, audioOnly: false);
                                // Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
                              }, showBottomDivider: false),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: OptionItem(AppLocalizations.of(context)!.moreInfo, showBottomDivider: false, onTap: () {
                            Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                          }),
                        ),
                        const SectionDivider(),
                        Container(
                          color: context.colors.surface,
                          child: OptionButtonItem(AppLocalizations.of(context)!.addFriend, () {
                            _openInviteFriendPage(context);
                          }, showBottomDivider: false),
                        ),
                      ],
                      const SizedBox(height: SectionDivider.gap),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrganizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _bottomRelationships.asMap().entries.map((entry) {
        final index = entry.key;
        final rel = entry.value;
        final org = _bottomOrganizations[rel.organizationId];
        final title = org?.name ?? '部门 ${rel.organizationId}';
        return OptionItem(
          title,
          showBottomDivider: index < _bottomRelationships.length - 1,
          onTap: () => _openOrganization(rel.organizationId),
        );
      }).toList(),
    );
  }

  Future<bool> _isFriend(String userId) async {
    if (Config.AI_ROBOTS.contains(userId)) {
      return true;
    }
    return await Imclient.isMyFriend(userId);
  }

  void _showSetDisplayNameDialog(BuildContext context, UserInfo userInfo) {
    TextEditingController controller = TextEditingController(text: userInfo.displayName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.modifyAlias),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: AppLocalizations.of(context)!.inputNickname),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.modifyMyInfo({ModifyMyInfoType.Modify_DisplayName: controller.text}, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.modifySuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.modifyFail}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        );
      },
    );
  }

  void _showSetAliasDialog(BuildContext context, UserInfo userInfo) {
    TextEditingController controller = TextEditingController(text: userInfo.friendAlias);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.setAlias),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: AppLocalizations.of(context)!.inputAlias),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.setFriendAlias(userInfo.userId, controller.text, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.setSuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.setFail}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserInfo userInfo, bool isFriend) {
    String? portrait;
    if (userInfo.portrait != null && userInfo.portrait!.isNotEmpty) {
      portrait = userInfo.portrait;
    }

    List<Widget> nameList = [];
    nameList.add(MeshUserName(
      userInfo,
      textAlign: TextAlign.left,
      style: AppText.lg,
    ));
    bool hasAlias = isFriend && userInfo.friendAlias != null && userInfo.friendAlias!.isNotEmpty;
    nameList.add(Container(
      margin: EdgeInsets.only(top: hasAlias ? 3 : 6),
    ));
    if (hasAlias) {
      nameList.add(Text(
        '${AppLocalizations.of(context)!.remark}:${userInfo.friendAlias!}',
        textAlign: TextAlign.left,
        style: AppText.xs,
      ));
      nameList.add(Container(
        margin: EdgeInsets.only(top: hasAlias ? 3 : 6),
      ));
    }
    nameList.add(Row(
      children: [
        Container(
            constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width / View.of(context).devicePixelRatio - 120),
            child: Text(
              AppLocalizations.of(context)!.wildfireId(userInfo.name),
              textAlign: TextAlign.left,
              style: AppText.xs.copyWith(color: context.colors.textSecondary),
              overflow: TextOverflow.ellipsis,
            )),
        if (isFriend && _isStarred)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.star, color: Colors.amber, size: 16),
          ),
      ],
    ));

    return Container(
      constraints: BoxConstraints(minHeight: LayoutScale.watchScale(context, 80.0, cap: LayoutScale.rowCap)),
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Portrait(portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 60, height: 60, borderRadius: 6),
            ),
            onTap: () {
              //show user portrait
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nameList,
            ),
          )
        ],
      ),
    );
  }

  void _handleMenuSelection(String value, bool isFriend) {
    switch (value) {
      case 'blacklist':
        _toggleBlacklist();
        break;
      case 'star':
        _toggleStar();
        break;
      case 'delete':
        _deleteFriend();
        break;
      case 'add_friend':
        _openInviteFriendPage(context);
        break;
    }
  }

  void _openInviteFriendPage(BuildContext context) {
    pushPage(context, InviteFriendPage(widget.userId));
  }

  void _toggleBlacklist() {
    Imclient.setBlackList(widget.userId, !_isBlacklisted, () {
      setState(() {
        _isBlacklisted = !_isBlacklisted;
      });
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
    }, (errorCode) {
      Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.failed}: $errorCode");
    });
  }

  void _toggleStar() {
    var contactListViewModel = Provider.of<ContactListViewModel>(context, listen: false);
    contactListViewModel.setFavUser(widget.userId, !_isStarred);
    setState(() {
      _isStarred = !_isStarred;
    });
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
  }

  void _deleteFriend() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteFriend),
          content: Text(AppLocalizations.of(context)!.deleteFriendConfirm),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.deleteFriend(widget.userId, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
                  Navigator.pop(context);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.failed}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: context.colors.danger)),
            ),
          ],
        );
      },
    );
  }
}
