import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/group_search_info.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';

enum SearchType {
  User,
  Friend,
  Group,
  Channel,
  Conversation,
}

class SearchViewModel extends ChangeNotifier {
  String? _keyword;
  List<UserInfo> _searchedUsers = [];
  List<UserInfo> _searchedFriends = [];
  List<ChannelInfo> _searchedChannels = [];
  List<ConversationSearchInfo> _searchedConversationInfos = [];
  List<GroupSearchInfo> _searchedGroupInfos = [];

  Map<SearchType, List<Object>> _groupedSearchResult = {};

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

  Map<SearchType, List<Object>> get groupedSearchResult {
    return _groupedSearchResult;
  }

  search(String keyword,
      {List<SearchType> searchTypes = const [SearchType.User, SearchType.Friend, SearchType.Channel, SearchType.Group, SearchType.Conversation]}) async {
    if (keyword == _keyword) {
      return;
    }
    _keyword = keyword;
    if (searchTypes.contains(SearchType.User)) {
      searchUser(keyword);
    }
    if (searchTypes.contains(SearchType.Friend)) {
      searchFriend(keyword);
    }
    if (searchTypes.contains(SearchType.Channel)) {
      searchChannel(keyword);
    }
    if (searchTypes.contains(SearchType.Conversation)) {
      searchConversation(keyword);
    }
    if (searchTypes.contains(SearchType.Group)) {
      searchGroup(keyword);
    }
  }

  searchUser(String keyword, {SearchUserType searchType = SearchUserType.SearchUserType_General, int page = 0}) async {
    _keyword = keyword;
    Completer<List<UserInfo>> completer = Completer();
    Imclient.searchUser(keyword, searchType.index, page, (List<UserInfo>? userInfos) {
      if (keyword == _keyword) {
        _searchedUsers = userInfos ?? [];
        _groupedSearchResult[SearchType.User] = _searchedUsers;
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
    _groupedSearchResult[SearchType.Friend] = _searchedFriends;
    notifyListeners();
  }

  searchChannel(String keyword) async {
    Imclient.searchChannel(keyword, (channelInfos) {
      _searchedChannels = channelInfos;
      _groupedSearchResult[SearchType.Channel] = _searchedChannels;
      notifyListeners();
    }, (err) {});
  }

  searchConversation(String keyword) async {
    _searchedConversationInfos = await Imclient.searchConversation(keyword, [ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
    _groupedSearchResult[SearchType.Conversation] = _searchedConversationInfos;
    notifyListeners();
  }

  searchGroup(String keyword) async {
    _searchedGroupInfos = await Imclient.searchGroups(keyword);
    _groupedSearchResult[SearchType.Group] = _searchedGroupInfos;
    notifyListeners();
  }
}
