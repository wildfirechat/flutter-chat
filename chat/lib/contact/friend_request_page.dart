import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';

import '../app_navigator.dart';
import '../config.dart';
import '../user_info_widget.dart';
import '../utils/mesh_user_name.dart';
import '../mesh/mesh_cache.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/layout_scale.dart';

class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({super.key});

  @override
  State<StatefulWidget> createState() => FriendRequestPageState();

}

class FriendRequestPageState extends State<FriendRequestPage> {
  List<FriendRequest> requests = [];
  Map<String, UserInfo> cachedUserInfos = {};

  @override
  void initState() {
    super.initState();
    Imclient.clearUnreadFriendRequestStatus();
    _loadFriendRequestAndUserInfos();
  }

  void _loadFriendRequestAndUserInfos() {
    Imclient.getIncommingFriendRequest().then((value) {
      List<String> userIds = [];
      for(var f in value) {
        userIds.add(f.target);
      }

      Imclient.getUserInfos(userIds).then((userInfos) {
        setState(() {
          for(var ui in userInfos) {
            cachedUserInfos[ui.userId] = ui;
          }
          requests = value;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      GestureDetector(
        onTap: () => _clearAll(context),
        child: const Row(
          children: [
            Icon(Icons.delete_outline_rounded),
            Padding(padding: EdgeInsets.only(left: 16)),
          ],
        ),
      )
    ];

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: "好友请求",
              actions: actions,
            )
          : AppBar(
              actions: actions,
              title: const Text("好友请求"),
            ),
      backgroundColor: isDesktopShell ? context.colors.chatBgDesktop : null,
      body: SafeArea(
        child: ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (context, __) => Divider(
            indent: 16.0 + LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) + 12.0,
          ),
          itemBuilder: _buildRow,
        ),
      ),
    );
  }

  void _loadUserInfo(String userId) {

  }

  Widget _buildRow(BuildContext context, int index) {
    FriendRequest request = requests[index];
    UserInfo? userInfo = cachedUserInfos[request.target];
    if(userInfo == null) {
      _loadUserInfo(request.target);
    }

    return AnimatedBuilder(
      animation: MeshCache.instance,
      builder: (context, child) {
        return InkWell(
          onTap: () => pushPage(context, UserInfoWidget(request.target)),
          hoverColor: context.colors.hoverOverlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Portrait(userInfo?.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      userInfo != null
                          ? MeshUserName(userInfo, style: AppText.lg, maxLines: 1, overflow: TextOverflow.ellipsis)
                          : Text("<${request.target}>", style: AppText.lg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (request.reason != null && request.reason!.isNotEmpty)
                        Text(
                          request.reason!,
                          style: AppText.sm.copyWith(color: context.colors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (request.status == FriendRequestStatus.WaitingAccept)
                  // 行内主行动,中档实底(微信「新的朋友」同款形态)。
                  FilledButton(
                    onPressed: () => _acceptRequest(request.target),
                    child: Text(AppLocalizations.of(context)!.friendRequestAccept),
                  )
                else
                  Text(
                    request.status == FriendRequestStatus.Accepted
                        ? AppLocalizations.of(context)!.friendRequestAccepted
                        : AppLocalizations.of(context)!.friendRequestRejected,
                    style: AppText.sm.copyWith(color: context.colors.textSecondary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _acceptRequest(String userId) {
    Imclient.handleFriendRequest(userId, true, "", () {
      Fluttertoast.showToast(msg: "已通过");
      _loadFriendRequestAndUserInfos();
    }, (errorCode) {
      if(errorCode == 19) {
        Fluttertoast.showToast(msg: "已过期");
      } else {
        Fluttertoast.showToast(msg: '网络错误：$errorCode');
      }
    });
  }

  void _clearAll(BuildContext context) {
    Imclient.clearFriendRequest(1);
    Navigator.pop(context);
  }
}