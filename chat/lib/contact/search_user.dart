import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/search/async_search_result_view.dart';
import 'package:chat/search/search_scaffold.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/widget/portrait.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../utils/mesh_user_name.dart';

/// 搜索用户(添加好友 / 在某个外部单位里找人)。
///
/// [domainId] 非空时只在该单位里搜,入口是单位资料页的「在此单位中查找用户」。
///
/// 交互按微信来:边打边搜(输入停 250ms 发起一次),搜不到给明确提示 —— 原先这页是
/// SearchDelegate,打字阶段 buildSuggestions 返回一个空 Container,非要按下键盘的
/// 搜索键才有反应,看上去就是「搜了没反应、也没提示」。
class SearchUserScreen extends StatelessWidget {
  final String? domainId;
  final String? hint;

  const SearchUserScreen({super.key, this.domainId, this.hint});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inDomain = domainId != null && domainId!.isNotEmpty;
    return SearchScaffold(
      hint: hint ?? l10n.searchUserFieldHint,
      builder: (context, query) {
        if (query.isEmpty) {
          return SearchStatusView(
            icon: Icons.person_search_outlined,
            message: inDomain
                ? l10n.searchInCurrentDomain
                : l10n.searchUserAddFriendHint,
          );
        }
        return AsyncSearchResultView<UserInfo>(
          query: query,
          onSearch: _searchUsers,
          emptyMessage: l10n.searchUserNotFound,
          itemBuilder: (context, userInfo) =>
              _UserResultItem(userInfo: userInfo),
        );
      },
    );
  }

  /// 服务端按「姓名 / 手机号」搜。SDK 走的是回调,这里包成 Future;失败时抛出错误码,
  /// 由 [AsyncSearchResultView] 展示为搜索失败(而不是和「没搜到」混为一谈)。
  Future<List<UserInfo>> _searchUsers(String keyword) {
    final completer = Completer<List<UserInfo>>();
    Imclient.searchUser(
        keyword, SearchUserType.SearchUserType_Name_Mobile.index, 0,
        (userInfos) {
      if (!completer.isCompleted) {
        completer.complete(userInfos ?? []);
      }
    }, (errorCode) {
      if (!completer.isCompleted) {
        completer.completeError(errorCode);
      }
    }, domainId: domainId);
    return completer.future;
  }
}

class _UserResultItem extends StatelessWidget {
  final UserInfo userInfo;

  const _UserResultItem({required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => UserInfoWidget(userInfo.userId)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Portrait(userInfo.portrait ?? Config.defaultUserPortrait,
                Config.defaultUserPortrait,
                width: 40, height: 40, borderRadius: 4.0),
            const SizedBox(width: 12),
            Expanded(
              child: MeshUserName(
                userInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.base.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
