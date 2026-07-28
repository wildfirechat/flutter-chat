import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/user_info_widget.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../utils/media_url_redirector.dart';
import '../utils/mesh_user_name.dart';

class SearchUserDelegate extends SearchDelegate<String> {
  final String? domainId;

  SearchUserDelegate({this.domainId, required String searchFieldHint}) : super(searchFieldLabel: searchFieldHint);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(onPressed: (){
        query = "";
        showSuggestions(context);
      }, icon: const Icon(Icons.clear)),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
          icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        if (query.isEmpty) {
          close(context, "");
        } else {
          query = "";
          showSuggestions(context);
        }
      },
    );
  }

  Future<List<UserInfo>> searchUsersInServer() async {
    if(query.isEmpty) {
      return [];
    }

    List<UserInfo> us = [];
    bool finish = false;
    Imclient.searchUser(query, SearchUserType.SearchUserType_Name_Mobile.index, 0, (userInfos) {
        us = userInfos!;
        finish = true;
    }, (errorCode) {
        finish = true;
    }, domainId: domainId);

    while(!finish) {
      await Future.delayed(const Duration(microseconds: 100));
    }
    return us;
  }

  late List<UserInfo> searchedUsers;

  Widget _buildRow(BuildContext context, int index) {
    UserInfo userInfo = searchedUsers[index];
    return GestureDetector(
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), child: SizedBox(width: 40, height: 40, child: (userInfo.portrait == null || userInfo.portrait!.isEmpty)?Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0):Image.network(MediaUrlRedirector.redirect(userInfo.portrait!), width: 40, height: 40,),),),
            Expanded(child: MeshUserName(userInfo, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      onTap: () => _toUserInfoView(context, userInfo),
    );
  }

  void _toUserInfoView(BuildContext context, UserInfo userInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<UserInfo>>(
        future: searchUsersInServer(),
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.done) {
            if(snapshot.data!.isEmpty) {
              return Center(child: Text(l10n.searchUserNotFound),);
            } else {
              searchedUsers = snapshot.data!;
              return ListView.separated(
                itemCount: searchedUsers.length,
                separatorBuilder: (_, __) => const Divider(indent: 56),
                itemBuilder: (context, index) => _buildRow(context, index),
              );
            }
          }
          return const Center(child: CircularProgressIndicator(),);
        }
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (domainId != null && domainId!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Text(l10n.searchInCurrentDomain),
      );
    }
    if(query.isNotEmpty) {
      return Container();
    } else {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Text(l10n.searchUserAddFriendHint),
      );
    }
  }
}