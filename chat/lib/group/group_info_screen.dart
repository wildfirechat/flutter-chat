import 'package:chat/app_theme.dart';
import 'package:chat/config.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/app_server.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/group/fav_group_event.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String? from;

  const GroupInfoScreen({super.key, required this.groupId, this.from});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _isLoading = false;
  String? _remotePortrait;
  // 群聊是否已保存到通讯录(收藏群组);桌面端据此显示底部「从通讯录移除」栏。
  bool _isFavGroup = false;

  @override
  void initState() {
    super.initState();
    // 延迟加载，避免 build 过程中调用接口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemotePortraitIfNeeded();
    });
    if (isDesktopShell) {
      Imclient.isFavGroup(widget.groupId).then((fav) {
        if (mounted && fav != _isFavGroup) {
          setState(() => _isFavGroup = fav);
        }
      });
    }
  }

  void _loadRemotePortraitIfNeeded() {
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    var groupInfo = groupViewModel.getGroupInfo(widget.groupId);
    if (groupInfo != null && groupInfo.memberDt == -1) {
      // 只有在未加入群组时才尝试从 AppServer 获取头像
      AppServer.getGroupPortrait(widget.groupId, (portrait) {
        if (mounted) {
          setState(() {
            _remotePortrait = portrait;
          });
        }
      }, (error) {
        // ignore
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<GroupViewModel, GroupInfo?>(
      selector: (context, groupViewModel) => groupViewModel.getGroupInfo(widget.groupId),
      shouldRebuild: (prev, next) {
        if (prev != next) return true;
        if (prev == null || next == null) return true;
        return prev.updateDt != next.updateDt || prev.memberDt != next.memberDt;
      },
      builder: (context, groupInfo, child) {
        if (groupInfo == null || groupInfo.updateDt == 0) {
          return Scaffold(
            backgroundColor: isDesktopShell ? context.colors.surface : null,
            appBar: isDesktopShell
                ? const PcPageHeader(bare: true)
                : AppBar(title: Text(AppLocalizations.of(context)!.groupInfo)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          backgroundColor: isDesktopShell ? context.colors.surface : null,
          // 桌面端:群名字就写在正文里,标题栏再写一遍「群组信息」是多余的。
          appBar: isDesktopShell
              ? const PcPageHeader(bare: true)
              : AppBar(title: Text(AppLocalizations.of(context)!.groupInfo)),
          body: _buildBody(context, groupInfo),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GroupInfo groupInfo) {
    String name = groupInfo.remark != null && groupInfo.remark!.isNotEmpty ? groupInfo.remark! : groupInfo.name ?? AppLocalizations.of(context)!.groupChat;

    // 优先使用本地 GroupInfo 的 portrait，如果本地没有且未加入群组，则尝试使用远程 portrait
    String portrait = '';
    if (groupInfo.portrait != null && groupInfo.portrait!.isNotEmpty) {
      portrait = MediaUrlRedirector.redirect(groupInfo.portrait!);
    } else if (_remotePortrait != null && _remotePortrait!.isNotEmpty) {
      portrait = MediaUrlRedirector.redirect(_remotePortrait!);
    }

    // 桌面端(参照微信 PC):居中头像/群名/群号 + 「进入群聊」,
    // 已保存到通讯录的群聊在底部固定一条「从通讯录移除」。
    if (isDesktopShell) {
      final l10n = AppLocalizations.of(context)!;
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              // 滚动视图横向是松约束,Column 会收缩到最宽子项再被靠左放置,
              // 撑满宽度后其居中对齐才真正水平居中。
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: CachedNetworkImage(
                        imageUrl: portrait.isNotEmpty ? portrait : Config.defaultGroupPortrait,
                        width: 80,
                        height: 80,
                        memCacheWidth: (80 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                        memCacheHeight: (80 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
                        errorWidget: (context, url, error) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: AppText.xl.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.groupIdLabel}: ${widget.groupId}',
                      style: AppText.sm.copyWith(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 40),
                    _buildActionButton(groupInfo),
                  ],
                ),
              ),
            ),
          ),
          if (_isFavGroup) _buildRemoveFromContactsBar(context),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: CachedNetworkImage(
                imageUrl: portrait.isNotEmpty ? portrait : Config.defaultGroupPortrait,
                width: 80,
                height: 80,
                memCacheWidth: (80 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                memCacheHeight: (80 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
                errorWidget: (context, url, error) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
              )),
          const SizedBox(height: 16),
          Text(
            name,
            style: AppText.xl.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context)!.groupIdLabel}: ${widget.groupId}',
            style: AppText.base.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          _buildActionButton(groupInfo),
        ],
      ),
    );
  }

  Widget _buildActionButton(GroupInfo groupInfo) {
    String buttonText;
    bool isJoined = false;

    if (groupInfo.memberDt < -1) {
      buttonText = AppLocalizations.of(context)!.joinGroup;
    } else if (groupInfo.memberDt == -1) {
      buttonText = AppLocalizations.of(context)!.joinGroup;
    } else {
      buttonText = AppLocalizations.of(context)!.enterGroup;
      isJoined = true;
    }

    // 观感来自全局按钮主题(app_theme.dart),两端只差布局:桌面定宽中档、移动通栏大档。
    return SizedBox(
      width: isDesktopShell ? 120 : double.infinity,
      child: FilledButton(
        onPressed: _isLoading ? null : () => _onAction(groupInfo, isJoined),
        style: isDesktopShell ? null : AppTheme.largeButtonStyle(),
        // 加载中按钮已禁用(灰底),spinner 用默认主色。
        child: _isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(buttonText),
      ),
    );
  }

  /// 底部「从通讯录移除」:危险色文字按钮。
  Widget _buildRemoveFromContactsBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: TextButton(
        onPressed: _confirmRemoveFromContacts,
        style: TextButton.styleFrom(foregroundColor: context.colors.danger),
        child: Text(l10n.removeFromContacts),
      ),
    );
  }

  void _confirmRemoveFromContacts() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeFromContacts),
        content: Text(l10n.removeFromContactsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeFromContacts();
            },
            child: Text(l10n.remove, style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
  }

  void _removeFromContacts() {
    Imclient.setFavGroup(widget.groupId, false, () {
      if (!mounted) {
        return;
      }
      _isFavGroup = false;
      Imclient.IMEventBus.fire(FavGroupUpdatedEvent(widget.groupId, false));
      // 本页在右栏的存在依据(通讯录中的群聊)已失效,清回占位欢迎页。
      closePage(context);
    }, (errorCode) {
      if (mounted) {
        Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.failed}: $errorCode");
      }
    });
  }

  void _onAction(GroupInfo groupInfo, bool isJoined) {
    if (isJoined) {
      _enterGroupChat();
    } else {
      _joinGroup();
    }
  }

  void _enterGroupChat() {
    if (isDesktopShell) {
      openConversation(context, Conversation(conversationType: ConversationType.Group, target: widget.groupId));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationScreen(
            Conversation(conversationType: ConversationType.Group, target: widget.groupId),
          ),
        ),
      );
    }
  }

  void _joinGroup() {
    setState(() {
      _isLoading = true;
    });

    Imclient.addGroupMembers(widget.groupId, [Imclient.currentUserId], () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _enterGroupChat();
      }
    }, (errorCode) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (errorCode == ErrorCode.joinGroupNeedVerify) {
          _showJoinGroupReasonDialog().then((reason) {
            if (reason != null) {
              Imclient.sendJoinGroupRequest(
                widget.groupId,
                [Imclient.currentUserId],
                reason: reason,
                successCallback: () {
                  Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)!.joinGroupRequestSent);
                },
                errorCallback: (code) {
                  Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)!.sendFailure);
                },
              );
            }
          });
        } else {
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context)!.joinFail(errorCode));
        }
      }
    });
  }

  Future<String?> _showJoinGroupReasonDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.joinGroupVerificationEnabled),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.pleaseInputJoinGroupReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}
