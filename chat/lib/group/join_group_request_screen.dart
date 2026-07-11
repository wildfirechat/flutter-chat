import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/join_group_request.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../user_info_widget.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/portrait.dart';
import '../app_navigator.dart';
import 'package:chat/theme/app_typography.dart';

/// 入群申请管理页面
///
/// 群主/管理员可查看并处理群成员的入群申请。申请记录包含主动申请和邀请入群两种类型。
class JoinGroupRequestScreen extends StatefulWidget {
  final String groupId;

  const JoinGroupRequestScreen({super.key, required this.groupId});

  @override
  State<JoinGroupRequestScreen> createState() => _JoinGroupRequestScreenState();
}

class _JoinGroupRequestScreenState extends State<JoinGroupRequestScreen> {
  List<JoinGroupRequest> _requests = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  final Set<String> _processingMemberIds = {};
  StreamSubscription<JoinGroupRequestUpdatedEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadRequests();
    _clearUnread();
    _eventSubscription = Imclient.IMEventBus.on<JoinGroupRequestUpdatedEvent>().listen((_) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _clearUnread();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    try {
      final members = await Imclient.getGroupMembers(widget.groupId);
      final me = members.firstWhere(
        (m) => m.memberId == Imclient.currentUserId,
        orElse: () {
          final m = GroupMember(type: GroupMemberType.Normal, createDt: 0);
          m.memberId = Imclient.currentUserId;
          m.alias = '';
          return m;
        },
      );
      if (mounted) {
        setState(() {
          _isAdmin = me.type == GroupMemberType.Owner || me.type == GroupMemberType.Manager;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadRequests() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // iOS 侧获取全部记录（-1），页面里同时展示已通过/已拒绝/已过期
      final requests = await Imclient.getJoinGroupRequests(
        groupId: widget.groupId,
        status: -1,
      );
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearUnread() async {
    try {
      await Imclient.clearJoinGroupRequestUnread(groupId: widget.groupId);
    } catch (e) {
      // ignore
    }
  }

  void _handleRequest(JoinGroupRequest request, bool accept) {
    final l10n = AppLocalizations.of(context)!;
    if (_processingMemberIds.contains(request.memberId)) return;
    setState(() {
      _processingMemberIds.add(request.memberId);
    });
    // iOS 侧对于主动申请（self-request）会把 requestUserId 填成 memberId，
    // 原生 SDK 在 inviter 为空时可能不会回调，因此 fallback 到 memberId。
    final inviterId = request.requestUserId?.isNotEmpty == true ? request.requestUserId! : request.memberId;
    Imclient.handleJoinGroupRequest(
      request.groupId,
      request.memberId,
      accept,
      inviterId: inviterId,
      successCallback: () {
        if (mounted) {
          setState(() {
            _processingMemberIds.remove(request.memberId);
          });
          Fluttertoast.showToast(msg: accept ? l10n.agree : l10n.reject);
        }
        _loadRequests();
      },
      errorCallback: (errorCode) {
        if (mounted) {
          setState(() {
            _processingMemberIds.remove(request.memberId);
          });
          Fluttertoast.showToast(msg: '${l10n.networkError}: $errorCode');
        }
      },
    );
  }

  void _deleteRequest(JoinGroupRequest request) {
    final l10n = AppLocalizations.of(context)!;
    final inviterId = request.requestUserId?.isNotEmpty == true ? request.requestUserId! : request.memberId;
    Imclient.clearJoinGroupRequest(
      request.groupId,
      request.memberId,
      inviterId: inviterId,
    ).then((success) {
      if (success) {
        Fluttertoast.showToast(msg: l10n.deleteSuccess);
        _loadRequests();
      } else {
        Fluttertoast.showToast(msg: l10n.deleteFailed);
      }
    }).catchError((_) {
      Fluttertoast.showToast(msg: l10n.networkError);
    });
  }

  void _clearAll() {
    final l10n = AppLocalizations.of(context)!;
    Imclient.clearJoinGroupRequest(widget.groupId, '').then((success) {
      if (success) {
        Fluttertoast.showToast(msg: l10n.deleteSuccess);
        _loadRequests();
      } else {
        Fluttertoast.showToast(msg: l10n.deleteFailed);
      }
    }).catchError((_) {
      Fluttertoast.showToast(msg: l10n.networkError);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.joinGroupRequests),
        actions: [
          if (_requests.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(l10n.clearJoinGroupRequests),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _isLoading && _requests.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? Center(child: Text(l10n.noJoinGroupRequests))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return _JoinGroupRequestItem(
                        request: request,
                        isAdmin: _isAdmin,
                        isProcessing: _processingMemberIds.contains(request.memberId),
                        onAgree: () => _handleRequest(request, true),
                        onReject: () => _handleRequest(request, false),
                        onDelete: () => _deleteRequest(request),
                      );
                    },
                  ),
      ),
    );
  }
}

class _JoinGroupRequestItem extends StatelessWidget {
  final JoinGroupRequest request;
  final bool isAdmin;
  final bool isProcessing;
  final VoidCallback onAgree;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _JoinGroupRequestItem({
    required this.request,
    required this.isAdmin,
    this.isProcessing = false,
    required this.onAgree,
    required this.onReject,
    required this.onDelete,
  });

  bool get _isExpired {
    if (request.status != JoinGroupRequestStatus.pending) return false;
    return DateTime.now().millisecondsSinceEpoch - request.timestamp > 7 * 24 * 60 * 60 * 1000;
  }

  String _userName(UserViewModel vm, String userId) {
    final user = vm.getUserInfo(userId);
    return user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.name?.isNotEmpty == true ? user.name! : userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, child) {
        final memberName = _userName(userViewModel, request.memberId);
        final requestUserName = request.requestUserId != null && request.requestUserId!.isNotEmpty
            ? _userName(userViewModel, request.requestUserId!)
            : memberName;
        final memberUserInfo = userViewModel.getUserInfo(request.memberId);
        final requestUserInfo = request.requestUserId != null && request.requestUserId!.isNotEmpty
            ? userViewModel.getUserInfo(request.requestUserId!)
            : memberUserInfo;

        return ListTile(
          leading: GestureDetector(
            onTap: () => openPage(context, UserInfoWidget(request.memberId)),
            child: Portrait(memberUserInfo.portrait ?? '', '', width: 44, height: 44, borderRadius: 6),
          ),
          title: _buildTitle(context, requestUserName, memberName, requestUserInfo.userId, request.memberId),
          subtitle: request.reason != null && request.reason!.isNotEmpty
              ? Text(
                  '${l10n.joinGroupReason}: ${request.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.xs.copyWith(color: Colors.grey),
                )
              : null,
          trailing: _buildTrailing(context),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, String requestUserName, String memberName,
      String requestUserId, String memberId) {
    final spans = <InlineSpan>[];
    final isSelfRequest = request.requestUserId == null || request.requestUserId == memberId;

    if (isSelfRequest) {
      final raw = AppLocalizations.of(context)!.requestJoinGroup(memberName);
      spans.add(_tapSpan(context, memberName, memberId));
      spans.add(TextSpan(text: raw.substring(memberName.length)));
    } else {
      final raw = AppLocalizations.of(context)!.inviteJoinGroup(requestUserName, memberName);
      int pos1 = raw.indexOf(requestUserName);
      int pos2 = raw.indexOf(memberName, pos1 + requestUserName.length);
      spans.add(TextSpan(text: raw.substring(0, pos1)));
      spans.add(_tapSpan(context, requestUserName, requestUserId));
      spans.add(TextSpan(text: raw.substring(pos1 + requestUserName.length, pos2)));
      spans.add(_tapSpan(context, memberName, memberId));
      spans.add(TextSpan(text: raw.substring(pos2 + memberName.length)));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppText.lg.copyWith(color: Colors.black87),
        children: spans,
      ),
    );
  }

  InlineSpan _tapSpan(BuildContext context, String text, String userId) {
    return TextSpan(
      text: text,
      style: const TextStyle(color: Color(0xFF576b95)),
      recognizer: TapGestureRecognizer()
        ..onTap = () => openPage(context, UserInfoWidget(userId)),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isProcessing) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (request.status == JoinGroupRequestStatus.pending && !_isExpired && isAdmin) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onReject,
            child: Text(l10n.reject),
          ),
          TextButton(
            onPressed: onAgree,
            child: Text(l10n.agree),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteJoinGroupRequest)),
            ],
          ),
        ],
      );
    }

    String statusLabel;
    if (request.status == JoinGroupRequestStatus.accepted) {
      statusLabel = l10n.accepted;
    } else if (request.status == JoinGroupRequestStatus.rejected) {
      statusLabel = l10n.rejected;
    } else if (_isExpired) {
      statusLabel = l10n.expired;
    } else {
      statusLabel = '';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusLabel.isNotEmpty)
          Text(statusLabel, style: AppText.sm.copyWith(color: Colors.grey)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'delete', child: Text(l10n.deleteJoinGroupRequest)),
          ],
        ),
      ],
    );
  }
}
