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
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    // 延迟加载，避免 build 过程中调用接口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemotePortraitIfNeeded();
    });
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
            appBar: isDesktopShell
                ? PcPageHeader(title: AppLocalizations.of(context)!.groupInfo)
                : AppBar(title: Text(AppLocalizations.of(context)!.groupInfo)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: isDesktopShell
              ? PcPageHeader(title: AppLocalizations.of(context)!.groupInfo)
              : AppBar(title: Text(AppLocalizations.of(context)!.groupInfo)),
          body: _buildBody(context, groupInfo),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GroupInfo groupInfo) {
    String name = groupInfo.remark != null && groupInfo.remark!.isNotEmpty ? groupInfo.remark! : groupInfo.name ?? '群聊';

    // 优先使用本地 GroupInfo 的 portrait，如果本地没有且未加入群组，则尝试使用远程 portrait
    String portrait = '';
    if (groupInfo.portrait != null && groupInfo.portrait!.isNotEmpty) {
      portrait = MediaUrlRedirector.redirect(groupInfo.portrait!);
    } else if (_remotePortrait != null && _remotePortrait!.isNotEmpty) {
      portrait = MediaUrlRedirector.redirect(_remotePortrait!);
    }

    if (isDesktopShell) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: CachedNetworkImage(
                imageUrl: portrait.isNotEmpty ? portrait : Config.defaultGroupPortrait,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
                errorWidget: (context, url, error) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              "群号: ${widget.groupId}",
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 40),
            Divider(height: 1, thickness: 0.5, color: context.colors.hairline),
            const SizedBox(height: 36),
            _buildActionButton(groupInfo),
          ],
        ),
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
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
                errorWidget: (context, url, error) => Image.asset(Config.defaultGroupPortrait, width: 80, height: 80, color: Colors.grey),
              )),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "群号: ${widget.groupId}",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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

    if (isDesktopShell) {
      return SizedBox(
        width: 120,
        height: 36,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _onAction(groupInfo, isJoined),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  buttonText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _onAction(groupInfo, isJoined),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(buttonText),
      ),
    );
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
