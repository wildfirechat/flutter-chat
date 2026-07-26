import 'dart:async';
import 'dart:convert';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/unread_count.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moment_comment_content.dart';
import 'moment_feed_content.dart';

///朋友圈内容类型
enum WFMContentType{
  WFMContent_Text_Type,
  WFMContent_Image_Type,
  WFMContent_Video_Type,
  WFMContent_Link_Type
}

///评论类型
enum WFMCommentType {
  WFMComment_Comment_Type,
  WFMComment_Thumbup_Type
}

///修改朋友圈设置属性
enum WFMUpdateUserProfileType {
  WFMUpdateUserProfileType_BackgroudUrl,
  WFMUpdateUserProfileType_StrangerVisiableCount,
  WFMUpdateUserProfileType_VisiableScope
}

///朋友圈可视范围
enum WFMVisiableScope {
  WFMVisiableScope_NoLimit,
  WFMVisiableScope_3Days,
  WFMVisiableScope_1Month,
  WFMVisiableScope_6Months,
}

///媒体信息
class FeedEntry {
  late String mediaUrl;
  String? thumbUrl;
  int? mediaWidth;
  int? mediaHeight;
}

///朋友圈条目
class Feed {
  int? feedId;
  late String sender;
  late WFMContentType type;
  String? text;
  List<FeedEntry>? medias;
  List<String>? mentionedUser;
  List<String>? toUsers;
  List<String>? excludeUsers;
  int? serverTime;
  String? extra;
  List<Comment> ? comments;
  bool hasMoreComments = false;
}

///朋友圈评论
class Comment {
  late int feedId;
  int? commentId;
  int? replyCommentId;
  late String sender;
  late WFMCommentType type;
  String? text;
  String? replyTo;
  int? serverTime;
  String? extra;
}

///朋友圈设置
class MomentProfiles {
  String? backgroundUrl;
  List<String>? blackList;
  List<String>? blockList;
  int? strangerVisiableCount;
  WFMVisiableScope? visiableScope;
  int? updateDt;
}

typedef OnReceiveNewCommentCallback = void Function(MomentCommentMessageContent comment);
typedef OnReceiveMentionedFeedCallback = void Function(MomentFeedMessageContent feed);

typedef MomentPostSuccessCallback = void Function(int feedId, int timestamp);
typedef FeedsSuccessCallback = void Function(List<Feed> feeds);
typedef ProfilesSuccessCallback = void Function(MomentProfiles profiles);
typedef FeedSuccessCallback = void Function(Feed feed);
typedef MomentVoidSuccessCallback = void Function();
typedef FailureCallback = void Function(int errorCode);

///朋友圈客户端
///
///纯 Dart 实现，底层通过 [Imclient.sendMomentsRequest] 与 IM 服务通信，
///同时支持 Android/iOS/鸿蒙/Windows/macOS/Linux。usePB 固定为 true，
///[getFeeds]/[getFeed] 使用 /moments_pb 路径。
class MomentClient {
  ///使用之前必须初始化
  static void init(OnReceiveNewCommentCallback newCommentCallback, OnReceiveMentionedFeedCallback mentionedFeedCallback) {
    MomentClientImpl.instance.init(newCommentCallback, mentionedFeedCallback);
    Imclient.registerMessageContent(commentContentMeta);
    Imclient.registerMessageContent(feedContentMeta);
  }

  ///发布朋友圈
  static Future<Feed> postFeed(WFMContentType type, {String? text, List<FeedEntry>? medias, List<String>? toUsers, List<String>? excludeUsers, List<String>? mentionedUsers, String? extra, void Function(int feedId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    return MomentClientImpl.instance.postFeed(type, text: text, medias: medias, toUsers: toUsers, excludeUsers: excludeUsers, mentionedUsers: mentionedUsers, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///删除朋友圈，朋友圈必须属于当前用户才能删除
  static void deleteFeed(int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    MomentClientImpl.instance.deleteFeed(feedId, successCallback, errorCallback);
  }

  ///批量获取朋友圈
  static void getFeeds(int fromIndex, int count, String? user, FeedsSuccessCallback feedsSuccessCallback, FailureCallback failureCallback) {
    MomentClientImpl.instance.getFeeds(fromIndex, count, user, feedsSuccessCallback, failureCallback);
  }

  ///获取单条朋友圈
  static void getFeed(int feedId, FeedSuccessCallback feedSuccessCallback, FailureCallback failureCallback) {
    MomentClientImpl.instance.getFeed(feedId, feedSuccessCallback, failureCallback);
  }

  ///发布评论或点赞
  static Future<Comment> postComment(WFMCommentType type, int feedId, {int? replyCommentId, String? text, String? replyTo, String? extra, void Function(int commentId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    return MomentClientImpl.instance.postComment(type, feedId, replyCommentId: replyCommentId, text: text, replyTo: replyTo, extra: extra, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///删除评论或点赞
  static void deleteComment(int commentId, int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    MomentClientImpl.instance.deleteComment(commentId, feedId, successCallback, errorCallback);
  }

  ///获取评论或提醒消息
  static Future<List<Message>> getMessages(int fromIndex, bool isNew) async {
    return MomentClientImpl.instance.getMessages(fromIndex, isNew);
  }

  ///获取朋友圈消息未读数量
  static Future<int> getUnreadCount() async {
    return MomentClientImpl.instance.getUnreadCount();
  }

  ///清除朋友圈消息未读数量
  static Future<void> clearUnreadStatus() async {
    return MomentClientImpl.instance.clearUnreadStatus();
  }

  ///为用户缓存数据
  static Future<void> storeCache(List<Feed> feeds, {String? userId}) async {
    return MomentClientImpl.instance.storeCache(feeds, userId: userId);
  }

  ///获取缓存的数据
  static Future<List<Feed>> restoreCache({String? userId}) async {
    return MomentClientImpl.instance.restoreCache(userId: userId);
  }

  ///获取朋友圈设置
  static void getUserProfile(ProfilesSuccessCallback successCallback, FailureCallback failureCallback, {String? userId}) {
    MomentClientImpl.instance.getUserProfile(userId, successCallback, failureCallback);
  }

  ///更新朋友圈设置
  static void updateMyProfile(WFMUpdateUserProfileType updateProfileType, String? strValue, int? intValue, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    MomentClientImpl.instance.updateMyProfile(updateProfileType, strValue, intValue, successCallback, failureCallback);
  }

  ///更新block和black的列表
  static void updateBlackOrBlockList(bool isBlock, List<String>? addList, List<String>? removeList, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    MomentClientImpl.instance.updateBlackOrBlockList(isBlock, addList, removeList, successCallback, failureCallback);
  }

  ///记录最后阅读时间
  static Future<void> updateLastReadTimestamp() async {
    return MomentClientImpl.instance.updateLastReadTimestamp();
  }

  ///获取最后阅读时间
  static Future<int> getLastReadTimestamp() async {
    return MomentClientImpl.instance.getLastReadTimestamp();
  }
}

///朋友圈客户端实现
class MomentClientImpl {
  MomentClientImpl._();

  static final MomentClientImpl _instance = MomentClientImpl._();
  static MomentClientImpl get instance => _instance;

  static late OnReceiveNewCommentCallback _receiveNewCommentCallback;
  static late OnReceiveMentionedFeedCallback _receiveMentionedFeedCallback;

  /// 朋友圈服务根路径，usePB=true。
  static const String _momentsPath = "moments";
  static const String _momentsPbPath = "moments_pb";

  void init(OnReceiveNewCommentCallback newCommentCallback,
      OnReceiveMentionedFeedCallback mentionedFeedCallback) {
    _receiveNewCommentCallback = newCommentCallback;
    _receiveMentionedFeedCallback = mentionedFeedCallback;

    // 监听 IM 下行消息，过滤出朋友圈相关消息（Single 会话、line=1）。
    Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
      for (var message in event.messages) {
        if (message.conversation.conversationType == ConversationType.Single &&
            message.conversation.line == 1) {
          if (message.content is MomentCommentMessageContent) {
            _receiveNewCommentCallback(
                message.content as MomentCommentMessageContent);
          } else if (message.content is MomentFeedMessageContent) {
            _receiveMentionedFeedCallback(
                message.content as MomentFeedMessageContent);
          }
        }
      }
    });

    // 连接成功后自动拉取前 20 条朋友圈，与 WFMomentService 行为一致。
    Imclient.IMEventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      if (event.connectionStatus == kConnectionStatusConnected) {
        getFeeds(0, 20, null, (_) {}, (_) {});
      }
    });
  }

  Future<Feed> postFeed(WFMContentType type,
      {String? text,
      List<FeedEntry>? medias,
      List<String>? toUsers,
      List<String>? excludeUsers,
      List<String>? mentionedUsers,
      String? extra,
      void Function(int feedId, int timestamp)? successCallback,
      void Function(int errorCode)? errorCallback}) async {
    Feed feed = Feed();
    feed.sender = Imclient.currentUserId;
    feed.type = type;
    feed.text = text;
    feed.medias = medias;
    feed.mentionedUser = mentionedUsers;
    feed.extra = extra;
    feed.toUsers = toUsers;
    feed.excludeUsers = excludeUsers;

    String data = jsonEncode(_feed2Map(feed));

    Completer<Feed> completer = Completer();
    Imclient.sendMomentsRequest(_path('/feed/post'), data, (String result) {
      Map<String, dynamic> map = jsonDecode(result);
      feed.feedId = map['id'];
      feed.serverTime = map['timestamp'];
      successCallback?.call(feed.feedId!, feed.serverTime!);
      completer.complete(feed);
    }, (int errorCode) {
      errorCallback?.call(errorCode);
      if (!completer.isCompleted) {
        completer.completeError(errorCode);
      }
    });
    return completer.future;
  }

  void deleteFeed(int feedId, MomentVoidSuccessCallback successCallback,
      FailureCallback errorCallback) {
    String data = jsonEncode({'id': feedId});
    Imclient.sendMomentsRequest(_path('/feed/recall'), data, (_) {
      successCallback();
    }, (int errorCode) {
      errorCallback(errorCode);
    });
  }

  void getFeeds(int fromIndex, int count, String? user,
      FeedsSuccessCallback feedsSuccessCallback, FailureCallback failureCallback) {
    Map<String, dynamic> dataDict = {};
    if (fromIndex > 0) {
      dataDict['feedId'] = fromIndex;
    }
    if (count > 0) {
      dataDict['count'] = count;
    }
    if (user != null) {
      dataDict['user'] = user;
    }

    Imclient.sendMomentsRequest(
        _pbPath('/feed/pull'), jsonEncode(dataDict), (String result) {
      List<dynamic> list = jsonDecode(result);
      List<Feed> feeds = [];
      for (var value in list) {
        if (value is Map<dynamic, dynamic>) {
          feeds.add(_feedFromMap(value));
        }
      }

      if (fromIndex == 0) {
        storeCache(feeds, userId: user);
      } else {
        restoreCache(userId: user).then((exist) {
          exist.addAll(feeds);
          storeCache(exist, userId: user);
        });
      }

      feedsSuccessCallback(feeds);
    }, (int errorCode) {
      failureCallback(errorCode);
    });
  }

  void getFeed(int feedId, FeedSuccessCallback feedSuccessCallback,
      FailureCallback failureCallback) {
    String data = jsonEncode({'feedId': feedId});
    Imclient.sendMomentsRequest(_pbPath('/feed/pull_one'), data, (String result) {
      Map<String, dynamic> map = jsonDecode(result);
      feedSuccessCallback(_feedFromMap(map));
    }, (int errorCode) {
      failureCallback(errorCode);
    });
  }

  Future<Comment> postComment(WFMCommentType type, int feedId,
      {int? replyCommentId,
      String? text,
      String? replyTo,
      String? extra,
      void Function(int commentId, int timestamp)? successCallback,
      void Function(int errorCode)? errorCallback}) async {
    Comment comment = Comment();
    comment.sender = Imclient.currentUserId;
    comment.feedId = feedId;
    comment.replyCommentId = replyCommentId;
    comment.type = type;
    comment.text = text;
    comment.replyTo = replyTo;
    comment.extra = extra;

    String data = jsonEncode(_comment2Map(comment));

    Completer<Comment> completer = Completer();
    Imclient.sendMomentsRequest(_path('/comment/post'), data, (String result) {
      Map<String, dynamic> map = jsonDecode(result);
      comment.commentId = map['id'];
      comment.serverTime = map['timestamp'];
      successCallback?.call(comment.commentId!, comment.serverTime!);
      completer.complete(comment);
    }, (int errorCode) {
      errorCallback?.call(errorCode);
      if (!completer.isCompleted) {
        completer.completeError(errorCode);
      }
    });
    return completer.future;
  }

  void deleteComment(int commentId, int feedId,
      MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    String data = jsonEncode({'id': commentId, 'id2': feedId});
    Imclient.sendMomentsRequest(_path('/comment/recall'), data, (_) {
      successCallback();
    }, (int errorCode) {
      errorCallback(errorCode);
    });
  }

  Future<List<Message>> getMessages(int fromIndex, bool isNew) async {
    List<MessageStatus> status =
        isNew ? [MessageStatus.Message_Status_Unread] : [];
    List<Message> messages = await Imclient.getConversationsMessageByStatus(
        [ConversationType.Single], [1], fromIndex, 100, status);
    return messages.where((message) {
      return message.content is MomentFeedMessageContent ||
          message.content is MomentCommentMessageContent;
    }).toList();
  }

  Future<int> getUnreadCount() async {
    UnreadCount unread = await Imclient.getConversationsUnreadCount(
        [ConversationType.Single], [1]);
    return unread.unread;
  }

  Future<void> clearUnreadStatus() async {
    await Imclient.clearConversationsUnreadStatus(
        [ConversationType.Single], [1]);
  }

  /// 本地缓存上限：只保留最新 50 条，避免翻页后全量 JSON 重写越来越大。
  static const int _maxCacheCount = 50;

  Future<void> storeCache(List<Feed> feeds, {String? userId}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = _cacheKey(userId);
    // feed 按时间倒序，截断尾部即可保留最新条目
    if (feeds.length > _maxCacheCount) {
      feeds = feeds.sublist(0, _maxCacheCount);
    }
    List<String> list = feeds.map((f) => jsonEncode(_feed2Map(f))).toList();
    await prefs.setStringList(key, list);
  }

  Future<List<Feed>> restoreCache({String? userId}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = _cacheKey(userId);
    List<String>? list = prefs.getStringList(key);
    if (list == null) return [];
    return list.map((s) => _feedFromMap(jsonDecode(s))).toList();
  }

  String _cacheKey(String? userId) {
    if (userId != null) {
      return 'feeds_$userId';
    } else {
      return 'feeds_all_${Imclient.currentUserId}';
    }
  }

  void getUserProfile(String? userId, ProfilesSuccessCallback successCallback,
      FailureCallback failureCallback) {
    String targetUserId = userId ?? Imclient.currentUserId;
    _profileFromStore(targetUserId).then((cachedProfile) {
      if (cachedProfile != null) {
        successCallback(cachedProfile);
      }

      Map<String, dynamic> dataDict = {'u': targetUserId};
      if (cachedProfile?.updateDt != null) {
        dataDict['d'] = cachedProfile!.updateDt;
      }

      Imclient.sendMomentsRequest(
          _path('/profiles/pull'), jsonEncode(dataDict), (String result) {
        Map<String, dynamic> map = jsonDecode(result);
        MomentProfiles profile = _profileFromMap(map);
        successCallback(profile);
        _profileToStore(targetUserId, profile);
      }, (int errorCode) {
        failureCallback(errorCode);
      });
    });
  }

  void updateMyProfile(WFMUpdateUserProfileType updateProfileType,
      String? strValue, int? intValue, MomentVoidSuccessCallback successCallback,
      FailureCallback errorCallback) {
    Map<String, dynamic> dataDict = {'t': updateProfileType.index};
    if (strValue != null && strValue.isNotEmpty) {
      dataDict['v'] = strValue;
    }
    if (intValue != null && intValue != 0) {
      dataDict['i'] = intValue;
    }

    Imclient.sendMomentsRequest(
        _path('/profiles/value/push'), jsonEncode(dataDict), (_) {
      successCallback();
    }, (int errorCode) {
      errorCallback(errorCode);
    });
  }

  void updateBlackOrBlockList(bool isBlock, List<String>? addList,
      List<String>? removeList, MomentVoidSuccessCallback successCallback,
      FailureCallback errorCallback) {
    Map<String, dynamic> dataDict = {'b': isBlock};
    if (addList != null && addList.isNotEmpty) {
      dataDict['al'] = addList;
    }
    if (removeList != null && removeList.isNotEmpty) {
      dataDict['rl'] = removeList;
    }

    Imclient.sendMomentsRequest(
        _path('/profiles/list/push'), jsonEncode(dataDict), (_) {
      successCallback();
    }, (int errorCode) {
      errorCallback(errorCode);
    });
  }

  Future<void> updateLastReadTimestamp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt('wfc_moment_lastreadtime', timestamp);
  }

  Future<int> getLastReadTimestamp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('wfc_moment_lastreadtime') ?? 0;
  }

  // ---- 路径构造 ----

  String _path(String api) => '/$_momentsPath$api';

  String _pbPath(String api) => '/$_momentsPbPath$api';

  // ---- 模型与 Map 转换 ----

  Feed _feedFromMap(Map<dynamic, dynamic> map) {
    Feed feed = Feed();
    feed.text = map["text"];
    feed.serverTime = map["timestamp"];
    feed.type = WFMContentType.values[map["type"]];
    feed.feedId = map["feedId"];
    feed.sender = map["sender"] ?? Imclient.currentUserId;
    if (map["medias"] != null) {
      List<dynamic> ms = map["medias"];
      feed.medias = [];
      for (var value in ms) {
        if (value is Map) {
          feed.medias!.add(entryFromMap(value));
        }
      }
    }
    if (map["to"] != null) {
      feed.toUsers = _toStringList(map["to"]);
    }
    if (map["ex"] != null) {
      feed.excludeUsers = _toStringList(map["ex"]);
    }
    if (map["mu"] != null) {
      feed.mentionedUser = _toStringList(map["mu"]);
    }
    feed.extra = map["extra"];
    if (map["comments"] != null) {
      feed.comments = [];
      List<dynamic> cs = map["comments"];
      for (var value in cs) {
        if (value is Map) {
          feed.comments!.add(_commentFromMap(value));
        }
      }
    }
    if (map["hasMore"] != null) {
      // JSON 接口返回 bool，protobuf 解码（usePB）返回 int（0/1），兼容两种形态。
      final hasMore = map["hasMore"];
      feed.hasMoreComments =
          hasMore is bool ? hasMore : (hasMore is int ? hasMore != 0 : false);
    }
    return feed;
  }

  Map<String, dynamic> _feed2Map(Feed feed) {
    Map<String, dynamic> map = {
      "sender": feed.sender,
      "type": feed.type.index,
      "hasMore": feed.hasMoreComments
    };
    if (feed.feedId != null) {
      map["feedId"] = feed.feedId!;
    }
    if (feed.text != null) {
      map["text"] = feed.text!;
    }
    if (feed.medias != null) {
      map["medias"] = feedEntryList2Map(feed.medias!);
    }
    if (feed.mentionedUser != null) {
      map["mu"] = feed.mentionedUser!;
    }
    if (feed.toUsers != null) {
      map["to"] = feed.toUsers!;
    }
    if (feed.excludeUsers != null) {
      map["ex"] = feed.excludeUsers!;
    }
    if (feed.serverTime != null) {
      map["timestamp"] = feed.serverTime!;
    }
    if (feed.extra != null) {
      map["extra"] = feed.extra!;
    }
    if (feed.comments != null) {
      map["comments"] = _commentList2Map(feed.comments!);
    }
    return map;
  }

  Comment _commentFromMap(Map<dynamic, dynamic> map) {
    Comment comment = Comment();
    comment.text = map["text"];
    comment.serverTime = map["serverTime"];
    comment.type = WFMCommentType.values[map["type"]];
    comment.feedId = map["feedId"];
    comment.commentId = map["commentId"];
    comment.sender = map["sender"] ?? Imclient.currentUserId;
    comment.extra = map["extra"];
    comment.replyTo = map["replyTo"];
    comment.replyCommentId = map["replyId"];
    return comment;
  }

  Map<String, dynamic> _comment2Map(Comment comment) {
    Map<String, dynamic> map = {
      "feedId": comment.feedId,
      "sender": comment.sender,
      "type": comment.type.index
    };
    if (comment.commentId != null) {
      map["commentId"] = comment.commentId!;
    }
    if (comment.replyCommentId != null) {
      map["replyId"] = comment.replyCommentId!;
    }
    if (comment.text != null) {
      map["text"] = comment.text!;
    }
    if (comment.replyTo != null) {
      map["replyTo"] = comment.replyTo!;
    }
    if (comment.serverTime != null) {
      map["serverTime"] = comment.serverTime!;
    }
    if (comment.extra != null) {
      map["extra"] = comment.extra!;
    }
    return map;
  }

  List<Map<String, dynamic>> _commentList2Map(List<Comment> comments) {
    List<Map<String, dynamic>> list = [];
    for (var value in comments) {
      list.add(_comment2Map(value));
    }
    return list;
  }

  List<String>? _toStringList(List<dynamic>? list) {
    if (list == null) return null;
    List<String> rs = [];
    for (var value in list) {
      if (value is String) {
        rs.add(value);
      }
    }
    return rs;
  }

  MomentProfiles _profileFromMap(Map<dynamic, dynamic> map) {
    MomentProfiles profiles = MomentProfiles();
    profiles.backgroundUrl = map['bgUrl'];
    profiles.blackList = _toStringList(map['blackList']);
    profiles.blockList = _toStringList(map['blockList']);
    profiles.strangerVisiableCount = map['svc'];
    if (map['visiableScope'] != null) {
      profiles.visiableScope = WFMVisiableScope.values[map['visiableScope']];
    }
    profiles.updateDt = map['updateDt'];
    return profiles;
  }

  Map<String, dynamic> _profile2Map(MomentProfiles profiles) {
    Map<String, dynamic> map = {};
    if (profiles.backgroundUrl != null && profiles.backgroundUrl!.isNotEmpty) {
      map['bgUrl'] = profiles.backgroundUrl!;
    }
    if (profiles.blackList != null) {
      map['blackList'] = profiles.blackList!;
    }
    if (profiles.blockList != null) {
      map['blockList'] = profiles.blockList!;
    }
    if (profiles.strangerVisiableCount != null &&
        profiles.strangerVisiableCount! != 0) {
      map['svc'] = profiles.strangerVisiableCount!;
    }
    if (profiles.visiableScope != null) {
      map['visiableScope'] = profiles.visiableScope!.index;
    }
    if (profiles.updateDt != null && profiles.updateDt! != 0) {
      map['updateDt'] = profiles.updateDt!;
    }
    return map;
  }

  Future<MomentProfiles?> _profileFromStore(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = 'moment_profile_$userId';
    String? jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      MomentProfiles profile = _profileFromMap(jsonDecode(jsonStr));
      if (profile.updateDt != null && profile.updateDt! != 0) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _profileToStore(String userId, MomentProfiles profile) async {
    if (profile.updateDt != null && profile.updateDt! != 0) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = 'moment_profile_$userId';
      await prefs.setString(key, jsonEncode(_profile2Map(profile)));
    }
  }

  static FeedEntry entryFromMap(Map<dynamic, dynamic> map) {
    FeedEntry entry = FeedEntry();
    entry.mediaUrl = map["m"];
    entry.thumbUrl = map["t"];
    entry.mediaWidth = map["w"];
    entry.mediaHeight = map["h"];
    return entry;
  }

  static Map<String, dynamic> feedEntry2Map(FeedEntry entry) {
    Map<String, dynamic> map = {"m": entry.mediaUrl};
    if (entry.thumbUrl != null) {
      map["t"] = entry.thumbUrl;
    }
    if (entry.mediaWidth != null) {
      map["w"] = entry.mediaWidth;
    }
    if (entry.mediaHeight != null) {
      map["h"] = entry.mediaHeight;
    }
    return map;
  }

  static List<Map<String, dynamic>> feedEntryList2Map(List<FeedEntry> entrys) {
    List<Map<String, dynamic>> list = [];
    for (var value in entrys) {
      list.add(feedEntry2Map(value));
    }
    return list;
  }
}
