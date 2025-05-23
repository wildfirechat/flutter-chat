import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/search/search_portal_result_view.dart';
import 'package:wfc_example/user_info_widget.dart';

import '../config.dart';

class SearchPortalDelegate extends SearchDelegate<String> {
  SearchPortalDelegate() : super(searchFieldLabel: "请输入");

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
          onPressed: () {
            query = "";
            showSuggestions(context);
          },
          icon: const Icon(Icons.clear)),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        close(context, '');
        // if (query.isEmpty) {
        //   close(context, "");
        // } else {
        //   query = "";
        //   showSuggestions(context);
        // }
      },
    );
  }

  Future<List<UserInfo>> searchUsersInServer() async {
    if (query.isEmpty) {
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

    while (!finish) {
      await Future.delayed(const Duration(microseconds: 100));
    }
    return us;
  }

  late List<UserInfo> searchedUsers;

  @override
  Widget buildResults(BuildContext context) {
    return SearchPortalResultView(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isNotEmpty) {
      return SearchPortalResultView(query);
    } else {
      return Container(
        margin: const EdgeInsets.all(16),
        child: const Text("输入关键字进行搜索"),
      );
    }
  }
}
