import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/user_info_widget.dart';

import '../config.dart';

class SearchUserDelegate extends SearchDelegate<String> {
  SearchUserDelegate() : super(searchFieldLabel: "请输入电话号码或者账户");

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
    });

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
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), child: SizedBox(width: 40, height: 40, child: (userInfo.portrait == null || userInfo.portrait!.isEmpty)?Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0):Image.network(userInfo.portrait!, width: 40, height: 40,),),),
            Text(userInfo.displayName!),
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
    return FutureBuilder<List<UserInfo>>(
        future: searchUsersInServer(),
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.done) {
            if(snapshot.data!.isEmpty) {
              return const Center(child: Text("没有找到呀，是不是输入的电话号码或者账户不对？"),);
            } else {
              searchedUsers = snapshot.data!;
              return ListView.builder(
                itemCount: searchedUsers.length,
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
    if(query.isNotEmpty) {
      return Container();
    } else {
      return Container(
        margin: const EdgeInsets.all(16),
        child: const Text("搜索用户添加好友！"),
      );
    }
  }
}