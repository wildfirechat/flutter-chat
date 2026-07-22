import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:moment/moment.dart';
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

import 'package:chat/call/av_call_launcher.dart';
import 'package:chat/pc/widgets/pc_icon_action.dart';
import 'package:chat/pc/widgets/pc_profile.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/pc/widgets/pc_pane_content.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/bottom_action_sheet.dart';

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
    // 返回键由 PcPageHeader 按导航栈自行判断:这一页是 push 出来的,组织架构还压在
    // 用户资料上面,返回键自然会出现。
    pushPage(context, OrganizationScreen(initialOrganizationId: organizationId));
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
          icon: const Icon(Icons.more_horiz_rounded),
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
      // 桌面端整页一张白底:正文限宽居中,分组之间只由弱分隔线交代,不套卡片
      // (面板本来就是白的,再套一层白卡片只会多出一圈没有意义的边框)。
      // 移动端仍是白卡片 + 凹槽灰。
      backgroundColor: isDesktopShell ? context.colors.surface : context.colors.primaryBackground,
      appBar: isDesktopShell
          // 标题只会是「用户信息」这个恒定名词,信息量为零 —— 去掉标题,但顶区(返回键、
          // 右上角菜单、三栏共用的 60px 水平线)必须留住,详见 PcPageHeader.bare。
          ? PcPageHeader(bare: true, actions: [actionsBuilder])
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

                return isDesktopShell
                    ? _buildDesktopBody(context, userInfo, isFriend, isMe)
                    : _buildMobileBody(context, userInfo, isFriend, isMe);
              },
            );
          },
        ),
      ),
    );
  }

  /// 桌面端右栏:限宽居中的一栏正文。头像/名字一组、资料行一组、底部图标动作一组,
  /// 组与组之间只用一条弱分隔线,没有卡片、没有边框、没有右箭头。
  Widget _buildDesktopBody(BuildContext context, UserInfo userInfo, bool isFriend, bool isMe) {
    final l10n = AppLocalizations.of(context)!;

    final List<Widget> infoRows = [];
    if (isMe) {
      // 自己这一行改的是昵称,不是备注 —— 备注是别人给自己起的名字。
      infoRows.add(PcProfileRow(
        label: l10n.nickname,
        value: userInfo.displayName,
        placeholder: l10n.modifyAlias,
        onTap: () => _showSetDisplayNameDialog(context, userInfo),
      ));
    } else if (isFriend) {
      infoRows.add(PcProfileRow(
        label: l10n.remark,
        value: userInfo.friendAlias,
        placeholder: l10n.setAlias,
        onTap: () => _showSetAliasDialog(context, userInfo),
      ));
    }
    if (!_loadingOrg && _bottomRelationships.isNotEmpty) {
      for (final rel in _bottomRelationships) {
        final org = _bottomOrganizations[rel.organizationId];
        infoRows.add(PcProfileRow(
          label: l10n.organization,
          value: org?.name ?? '${rel.organizationId}',
          onTap: () => _openOrganization(rel.organizationId),
        ));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: PcPaneContent(
        maxWidth: kPcProfileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDesktopProfile(context, userInfo, isFriend),
            const PcProfileDivider(),
            if (infoRows.isNotEmpty) ...[
              ...infoRows,
              const PcProfileDivider(),
            ],
            PcProfileRow(
              label: l10n.moreInfo,
              onTap: () => Fluttertoast.showToast(msg: l10n.methodNotImpl),
            ),
            const PcProfileDivider(),
            _buildDesktopActions(context, isFriend, isMe),
          ],
        ),
      ),
    );
  }

  /// 头像 + 名字 + 野火号。
  Widget _buildDesktopProfile(BuildContext context, UserInfo userInfo, bool isFriend) {
    final portrait = (userInfo.portrait?.isNotEmpty ?? false) ? userInfo.portrait! : Config.defaultUserPortrait;
    return PcProfileHeader(
      leading: Portrait(portrait, Config.defaultUserPortrait, width: 64, height: 64, borderRadius: 4),
      title: MeshUserName(
        userInfo,
        style: PcProfileHeader.titleStyle(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: AppLocalizations.of(context)!.wildfireId(userInfo.name),
      trailing: isFriend && _isStarred ? const Icon(Icons.star, color: Colors.amber, size: 16) : null,
    );
  }

  /// 发消息/通话/加好友:图标在上、文字在下,与 PC 用户卡片同一个形态。
  /// 原先用的 OptionButtonItem 默认色是 danger,那是给「清空聊天记录」「解散群」
  /// 这类操作用的(其余调用方全是这类),不该拿来做发消息。
  Widget _buildDesktopActions(BuildContext context, bool isFriend, bool isMe) {
    final l10n = AppLocalizations.of(context)!;
    final accent = context.colors.accent;
    final List<Widget> actions = [];
    if (isMe || isFriend) {
      actions.add(PcIconAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: l10n.sendMsg,
        labelColor: accent,
        onTap: () => _openSingleConversation(context),
      ));
    }
    // 给自己打电话没意义;AI 机器人也没有音视频能力(_isFriend 对机器人恒为 true)。
    if (isFriend && !isMe && !Config.AI_ROBOTS.contains(widget.userId)) {
      actions.add(PcIconAction(
        icon: Icons.call_outlined,
        label: l10n.audioCallAction,
        labelColor: accent,
        onTap: () => startSingleAvCall(context, widget.userId, audioOnly: true),
      ));
      actions.add(PcIconAction(
        icon: Icons.videocam_outlined,
        label: l10n.videoCallAction,
        labelColor: accent,
        onTap: () => startSingleAvCall(context, widget.userId, audioOnly: false),
      ));
    }
    if (!isMe && !isFriend) {
      actions.add(PcIconAction(
        icon: Icons.person_add_alt_1_outlined,
        label: l10n.addFriend,
        labelColor: accent,
        onTap: () => _openInviteFriendPage(context),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      // 译文过长时换行而非溢出(同 PC 用户卡片)。
      child: Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 8, children: actions),
    );
  }

  /// 移动端:整页凹槽灰 + 白卡片分组,由 SectionDivider 交代分组间隙。
  Widget _buildMobileBody(BuildContext context, UserInfo userInfo, bool isFriend, bool isMe) {
    final l10n = AppLocalizations.of(context)!;
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
          const SectionDivider(),
          Container(
            color: context.colors.surface,
            child: Column(
              children: [
                if (Config.ENABLE_MOMENTS)
                  OptionItem(l10n.momentWindowTitle, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              FeedListPage(userId: widget.userId)),
                    );
                  }),
                if (isMe)
                  OptionItem(l10n.modifyAlias, onTap: () {
                    _showSetDisplayNameDialog(context, userInfo);
                  })
                else if (isFriend)
                  OptionItem(l10n.setAlias, onTap: () {
                    _showSetAliasDialog(context, userInfo);
                  }),
                OptionItem(l10n.moreInfo, showBottomDivider: false, onTap: () {
                  Fluttertoast.showToast(msg: l10n.methodNotImpl);
                }),
              ],
            ),
          ),
          const SectionDivider(),
          Container(
            color: context.colors.surface,
            child: Column(
              children: [
                OptionButtonItem(
                  isMe || isFriend ? l10n.sendMsg : l10n.addFriend,
                  () {
                    if (isMe || isFriend) {
                      _openSingleConversation(context);
                    } else {
                      _openInviteFriendPage(context);
                    }
                  },
                  // 发消息/加好友不是危险操作,不该走 OptionButtonItem 的 danger 默认色。
                  titleColor: context.colors.accent,
                  showBottomDivider: isFriend && !isMe && !Config.AI_ROBOTS.contains(widget.userId),
                ),
                if (isFriend && !isMe && !Config.AI_ROBOTS.contains(widget.userId))
                  OptionButtonItem(
                    l10n.audioVideoCall,
                    () {
                      showBottomActionSheet(
                        context: context,
                        items: [
                          BottomActionSheetItem(
                            label: AppLocalizations.of(context)!.videoCallAction,
                            icon: Icons.videocam_rounded,
                            onTap: () {
                              startSingleAvCall(context, widget.userId, audioOnly: false);
                            },
                          ),
                          BottomActionSheetItem(
                            label: AppLocalizations.of(context)!.audioCallAction,
                            icon: Icons.call_rounded,
                            onTap: () {
                              startSingleAvCall(context, widget.userId, audioOnly: true);
                            },
                          ),
                        ],
                      );
                    },
                    titleColor: context.colors.accent,
                    showBottomDivider: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: SectionDivider.gap),
        ],
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
        // 这里原先按「窗口宽度 − 120」限宽 —— 桌面端这一页只占右栏(窗口宽减侧栏和中栏),
        // 那个值大出一大截,等于没限。宽度该由所在容器给,交给 Flexible。
        Flexible(
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
