import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';

class SearchViewModel extends ChangeNotifier {
  String? _keyword;
  List<UserInfo> _searchedUsers = [];
  List<UserInfo> _searchedFriends = [];
  List<ChannelInfo> _searchedChannels = [];
  List<ConversationSearchInfo> _searchedConversationInfos = [];
  List<GroupSearchInfo> _searchedGroupInfos = [];

  List<UserInfo> get searchedUsers {
    return _searchedUsers;
  }

  List<UserInfo> get searchedFriends {
    return _searchedFriends;
  }

  get searchedChannels {
    return _searchedChannels;
  }

  get searchedConversationInfos {
    return _searchedConversationInfos;
  }

  get searchedGroupInfos {
    return _searchedGroupInfos;
  }

  search(String keyword) async {
    if (keyword == _keyword) {
      return;
    }
    _keyword = keyword;
    searchUser(keyword);
    searchFriend(keyword);
    searchChannel(keyword);
    searchConversation(keyword);
    searchGroup(keyword);
  }

  searchUser(String keyword, {SearchUserType searchType = SearchUserType.SearchUserType_General, int page = 0}) async {
    _keyword = keyword;
    Completer<List<UserInfo>> completer = Completer();
    Imclient.searchUser(keyword, searchType.index, page, (List<UserInfo>? userInfos) {
      if (keyword == _keyword) {
        _searchedUsers = userInfos ?? [];
        completer.complete(userInfos);
        notifyListeners();
      }
    }, (errorCode) {
      // 处理错误
      print("Error occurred: $errorCode");
      completer.completeError(errorCode);
    });
    return completer.future;
  }

  searchFriend(String keyword) async {
    _searchedFriends = await Imclient.searchFriends(keyword);
    notifyListeners();
  }

  searchChannel(String keyword) async {
    Imclient.searchChannel(keyword, (channelInfos) {
      _searchedChannels = channelInfos;
      notifyListeners();
    }, (err) {});
  }

  searchConversation(String keyword) async {
    _searchedConversationInfos = await Imclient.searchConversation(keyword, [ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
    notifyListeners();
  }

  searchGroup(String keyword) async {
    _searchedGroupInfos = await Imclient.searchGroups(keyword);
  }
}
