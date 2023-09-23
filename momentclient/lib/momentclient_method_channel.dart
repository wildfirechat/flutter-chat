import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:momentclient/moment_comment_content.dart';
import 'package:momentclient/moment_feed_content.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'momentclient.dart';

/// An implementation of [MomentclientPlatform] that uses method channels.
class MethodChannelMomentClient extends PlatformInterface {
  /// Constructs a MomentclientPlatform.
  MethodChannelMomentClient() : super(token: _token);

  static final Object _token = Object();

  static MethodChannelMomentClient _instance = MethodChannelMomentClient();

  /// The default instance of [MomentclientPlatform] to use.
  ///
  /// Defaults to [MethodChannelMomentClient].
  static MethodChannelMomentClient get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MomentclientPlatform] when
  /// they register themselves.
  static set instance(MethodChannelMomentClient instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('momentclient');


  static int _requestId = 0;
  static final Map<int, PostSuccessCallback> _successCallbackMap = {};
  static final Map<int, MomentVoidSuccessCallback> _voidSuccessCallbackMap = {};
  static final Map<int, ProfilesSuccessCallback> _profilesSuccessCallbackMap = {};
  static final Map<int, FeedsSuccessCallback> _feedsSuccessCallbackMap = {};
  static final Map<int, FeedSuccessCallback> _feedSuccessCallbackMap = {};
  static final Map<int, FailureCallback> _errorCallbackMap = {};


  static late  OnReceiveNewCommentCallback _receiveNewCommentCallback;
  static late  OnReceiveMentionedFeedCallback _receiveMentionedFeedCallback;

  void init(OnReceiveNewCommentCallback newCommentCallback, OnReceiveMentionedFeedCallback mentionedFeedCallback) {
    _receiveNewCommentCallback = newCommentCallback;
    _receiveMentionedFeedCallback = mentionedFeedCallback;
    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onReceiveNewComment':
          Map<dynamic, dynamic> args = call.arguments;
          MessageContent content = Imclient.contentFromMap(args['comment']);
          if(content is MomentCommentMessageContent) {
            _receiveNewCommentCallback(content);
          }
          break;
        case 'onReceiveMentionedFeed':
          Map<dynamic, dynamic> args = call.arguments;
          MessageContent content = Imclient.contentFromMap(args);
          if(content is MomentFeedMessageContent) {
            _receiveMentionedFeedCallback(content);
          }
          break;
        case 'postFeedSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int feedId = args['feedId'];
          int timestamp = args['timestamp'];
          PostSuccessCallback? callback = _successCallbackMap[requestId];
          if(callback != null) {
            callback(feedId, timestamp);
            _removeAllOperationCallback(requestId);
          }
          break;
        case 'postCommentSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int commentId = args['commentId'];
          int timestamp = args['timestamp'];
          PostSuccessCallback? callback = _successCallbackMap[requestId];
          if(callback != null) {
            callback(commentId, timestamp);
            _removeAllOperationCallback(requestId);
          }
          break;
        case 'getFeedsSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> feeds = args['feeds'];
          FeedsSuccessCallback? feedsSuccessCallback = _feedsSuccessCallbackMap[requestId];
          if(feedsSuccessCallback != null) {
            feedsSuccessCallback(_feedListFromMap(feeds));
            _removeAllOperationCallback(requestId);
          }
          break;
        case 'getFeedSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> feed = args['feed'];
          FeedSuccessCallback? feedSuccessCallback = _feedSuccessCallbackMap[requestId];
          if(feedSuccessCallback != null) {
            feedSuccessCallback(_feedFromMap(feed));
            _removeAllOperationCallback(requestId);
          }
          break;
        case 'getProfileSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> profile = args['profile'];
          ProfilesSuccessCallback? profilesSuccessCallback = _profilesSuccessCallbackMap[requestId];
          if(profilesSuccessCallback != null) {
            profilesSuccessCallback(_profileFromMap(profile));
            _removeAllOperationCallback(requestId);
          }
          break;
        case 'onOperationVoidSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          var callback = _voidSuccessCallbackMap[requestId];
          if (callback != null) {
            callback();
          }
          _removeAllOperationCallback(requestId);
          break;
        case 'onOperationFailure':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int errorCode = args['errorCode'];
          var callback = _errorCallbackMap[requestId];
          if (callback != null) {
            callback(errorCode);
            _removeAllOperationCallback(requestId);
          }
          break;
        default:
          print("Unknown event:${call.method}");
          //should not be here!
          break;
      }
    });
  }

  void _removeAllOperationCallback(int requestId) {
    _successCallbackMap.remove(requestId);
    _errorCallbackMap.remove(requestId);
    _voidSuccessCallbackMap.remove(requestId);
    _profilesSuccessCallbackMap.remove(requestId);
    _feedsSuccessCallbackMap.remove(requestId);
    _feedSuccessCallbackMap.remove(requestId);
  }

  Future<Feed> postFeed(WFMContentType type, {String? text, List<FeedEntry>? medias, List<String>? toUsers, List<String>? excludeUsers, List<String>? mentionedUsers, String? extra, void Function(int feedId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    int requestId = _requestId++;
    if(successCallback != null) {
      _successCallbackMap[requestId] = successCallback;
    }
    if(errorCallback != null) {
      _errorCallbackMap[requestId] = errorCallback;
    }

    Map<String, dynamic> args = {
      "requestId": requestId,
      "type": type.index
    };

    if (text != null) {
      args['text'] = text;
    }
    if(medias != null) {
      List<Map<String, dynamic>> list = [];
      for (var value in medias) {
        list.add(feedEntry2Map(value));
      }
      args["medias"] = medias;
    }

    if(toUsers != null) {
      args["toUsers"] = toUsers;
    }

    if(excludeUsers != null) {
      args["excludeUsers"] = excludeUsers;
    }

    if(mentionedUsers != null) {
      args["mentionedUsers"] = mentionedUsers;
    }

    if(extra != null) {
      args["extra"] = extra;
    }

    Map<dynamic, dynamic> fm = await methodChannel.invokeMethod('postFeed', args);
    return _feedFromMap(fm)!;
  }

  void deleteFeed(int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    int requestId = _requestId++;
    _voidSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod('deleteFeed', {'requestId':requestId, 'feedId':feedId});
  }

  void getFeeds(int fromIndex, int count, String? user, FeedsSuccessCallback feedsSuccessCallback, FailureCallback failureCallback) {
    int requestId = _requestId++;
    _feedsSuccessCallbackMap[requestId] = feedsSuccessCallback;
    _errorCallbackMap[requestId] = failureCallback;
    Map args = {'requestId':requestId, 'fromIndex':fromIndex, 'count':count};
    if(user != null) {
      args['user'] = user;
    }
    methodChannel.invokeMethod('getFeeds', args);
  }

  void getFeed(int feedId, FeedSuccessCallback feedSuccessCallback, FailureCallback failureCallback) {
    int requestId = _requestId++;
    _feedSuccessCallbackMap[requestId] = feedSuccessCallback;
    _errorCallbackMap[requestId] = failureCallback;
    methodChannel.invokeMethod('getFeed', {'requestId':requestId, 'feedId':feedId});
  }

  Future<Comment> postComment(WFMCommentType type, int feedId, {int? replyCommentId, String? text, String? replyTo, String? extra, void Function(int commentId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    int requestId = _requestId++;
    if(successCallback != null) {
      _successCallbackMap[requestId] = successCallback;
    }
    if(errorCallback != null) {
      _errorCallbackMap[requestId] = errorCallback;
    }

    Map<String, dynamic> args = {
      "requestId": requestId,
      "type": type.index,
      "feedId": feedId
    };

    if(replyCommentId != null) {
      args['replyCommentId'] = replyCommentId;
    }

    if (text != null) {
      args['text'] = text;
    }

    if (replyTo != null) {
      args['replyTo'] = replyTo;
    }

    if(extra != null) {
      args["extra"] = extra;
    }

    Map<dynamic, dynamic> fm = await methodChannel.invokeMethod('postComment', args);
    return _commentFromMap(fm)!;
  }

  void deleteComment(int commentId, int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    int requestId = _requestId++;
    _voidSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod('deleteComment', {'requestId':requestId, 'commentId':commentId, 'feedId':feedId});
  }

  Future<List<Message>> getMessages(int fromIndex, bool isNew) async {
    List list = await methodChannel.invokeMethod('getMessages', {"isNew":isNew, "fromIndex":fromIndex});
    List<Message> ms = [];
    for (var value in list) {
      if(value is Map) {
        ms.add(Imclient.messageFromMap(value));
      }
    }
    return ms;
  }

  Future<int> getUnreadCount() async {
    return await methodChannel.invokeMethod('getUnreadCount');
  }

  Future<void> clearUnreadStatus() async {
    return await methodChannel.invokeMethod('clearUnreadStatus');
  }

  Future<void> storeCache(List<Feed> feeds, String? userId) async {
    Map args = {"feeds":_feedList2Map(feeds)};
    if(userId != null) {
      args["userId"] = userId;
    }
    return await methodChannel.invokeMethod('storeCache', args);
  }

  Future<List<Feed>> restoreCache({String? userId}) async {
    Map args = {};
    if(userId != null) {
      args['userId'] = userId!;
    }
    List list = await methodChannel.invokeMethod('restoreCache', args);
    return _feedListFromMap(list);
  }

  void getUserProfile(String? userId, ProfilesSuccessCallback successCallback, FailureCallback failureCallback) {
    int requestId = _requestId++;
    _profilesSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = failureCallback;
    methodChannel.invokeMethod('getUserProfile', {'requestId':requestId, 'userId':userId});
  }

  void updateMyProfile(WFMUpdateUserProfileType updateProfileType, String? strValue, int? intValue, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    int requestId = _requestId++;
    _voidSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = failureCallback;
    Map args = {'requestId':requestId, 'updateProfileType':updateProfileType.index};
    if(strValue != null) {
      args['strValue'] = strValue;
    }
    if(intValue != null) {
      args['intValue'] = intValue;
    }
    methodChannel.invokeMethod('updateMyProfile', args);
  }

  void updateBlackOrBlockList(bool isBlock, List<String>? addList, List<String>? removeList, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    int requestId = _requestId++;
    _voidSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = failureCallback;
    Map args = {'requestId':requestId, 'isBlock':isBlock};
    if(addList != null) {
      args['addList'] = addList;
    }
    if(removeList != null) {
      args['removeList'] = removeList;
    }
    methodChannel.invokeMethod('updateBlackOrBlockList', args);
  }

  Future<void> updateLastReadTimestamp() async {
    return await methodChannel.invokeMethod('updateLastReadTimestamp');
  }

  Future<int> getLastReadTimestamp() async {
    int ts = await methodChannel.invokeMethod('getLastReadTimestamp');
    return ts;
  }

  List<Feed> _feedListFromMap(List<dynamic> list) {
    List<Feed> feeds = [];
    for (var value in list) {
      if(value is Map<dynamic, dynamic>) {
        Map<dynamic, dynamic> map = value;
        feeds.add(_feedFromMap(map));
      }
    }
    return feeds;
  }

  Feed _feedFromMap(Map<dynamic, dynamic> map) {
    Feed feed = Feed();
    feed.feedId = map["feedId"];
    if(map["sender"] != null) {
      feed.sender = map["sender"];
    } else {
      feed.sender = Imclient.currentUserId;
    }
    feed.type = WFMContentType.values[map["type"]];
    feed.text = map["text"];
    if(map["medias"] != null) {
      List<dynamic> ms = map["medias"];
      feed.medias = [];

      for (var value in ms) {
        if(value is Map) {
          feed.medias?.add(entryFromMap(value));
        }
      }
    }
    feed.mentionedUser = map["mentionedUser"];
    feed.toUsers = map["toUsers"];
    feed.excludeUsers = map["excludeUsers"];
    feed.serverTime = map["timestamp"];
    feed.extra = map["extra"];
    if(map["comments"] != null) {
      feed.comments = [];
      List<dynamic> cs = map["comments"];
      for (var value in cs) {
        if(value is Map) {
          feed.comments!.add(_commentFromMap(value));
        }
      }
    }
    if(map["hasMoreComments"] != null) {
      feed.hasMoreComments = map["hasMoreComments"];
    }
    return feed;
  }

  Comment _commentFromMap(Map<dynamic, dynamic> map) {
    Comment comment = Comment();
    comment.feedId = map["feedId"];
    comment.commentId = map["commentId"];
    comment.replyCommentId = map["replyId"];
    comment.sender = map["sender"];
    comment.type = WFMCommentType.values[map["type"]];
    comment.text = map["text"];
    comment.replyTo = map["replyTo"];
    comment.serverTime = map["serverTime"];
    comment.extra = map["extra"];

    return comment;
  }

  static FeedEntry entryFromMap(Map<dynamic, dynamic> map) {
    FeedEntry entry = FeedEntry();
    entry.mediaUrl = map["m"];
    entry.thumbUrl = map["t"];
    entry.mediaWidth = map["w"];
    entry.mediaHeight = map["h"];
    return entry;
  }

  List<String>? _toStringList(List<dynamic>? list) {
    if(list == null) {
      return null;
    }

    List<String> rs = [];
    for (var value in list) {
      if(value is String) {
        rs.add(value);
      }
    }

    return rs;
  }

  MomentProfiles _profileFromMap(Map<dynamic, dynamic> map) {
    MomentProfiles profiles = MomentProfiles();
    profiles.backgroundUrl = map['backgroundUrl'];
    profiles.blackList = _toStringList(map['blackList']);
    profiles.blockList = _toStringList(map['blockList']);
    profiles.strangerVisiableCount = map['svc'];
    if(map['visiableScope']!=null) {
      profiles.visiableScope = WFMVisiableScope.values[map['visiableScope']];
    }
    profiles.updateDt = map['updateDt'];

    return profiles;
  }

  List<Map<String, dynamic>> _feedList2Map(List<Feed> feeds) {
    List<Map<String, dynamic>> list = [];
    for (var value in feeds) {
      list.add(_feed2Map(value));
    }
    return list;
  }

  Map<String, dynamic> _feed2Map(Feed feed) {
    Map<String, dynamic> map = {"sender":feed.sender, "type":feed.type.index, "hasMoreComments":feed.hasMoreComments};
    if(feed.feedId != null) {
      map["feedId"] = feed.feedId!;
    }
    if(feed.text != null) {
      map["text"] = feed.text!;
    }
    if(feed.medias != null) {
      map["medias"] = feedEntryList2Map(feed.medias!);
    }
    if(feed.mentionedUser != null) {
      map["mentionedUser"] = feed.mentionedUser!;
    }
    if(feed.toUsers != null) {
      map["toUsers"] = feed.toUsers!;
    }
    if(feed.excludeUsers != null) {
      map["excludeUsers"] = feed.excludeUsers!;
    }
    if(feed.serverTime != null) {
      map["serverTime"] = feed.serverTime!;
    }
    if(feed.extra != null) {
      map["extra"] = feed.extra!;
    }
    if(feed.comments != null) {
      map["comments"] = _commentList2Map(feed.comments!);
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

  static Map<String, dynamic> feedEntry2Map(FeedEntry entry) {
    Map<String, dynamic> map = {"m":entry.mediaUrl};
    if(entry.thumbUrl != null) {
      map["t"] = entry.thumbUrl;
    }
    if(entry.mediaWidth != null) {
      map["w"] = entry.mediaWidth;
    }
    if(entry.mediaHeight != null) {
      map["h"] = entry.mediaHeight;
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

  Map<String, dynamic> _comment2Map(Comment comment) {
    Map<String, dynamic> map = {"feedId":comment.feedId, "sender":comment.sender, "type":comment.type.index};
    if(comment.commentId != null) {
      map["commentUid"] = comment.commentId;
    }
    if(comment.replyCommentId != null) {
      map["replyCommentUid"] = comment.replyCommentId;
    }
    if(comment.text != null) {
      map["text"] = comment.text;
    }
    if(comment.replyTo != null) {
      map["replyTo"] = comment.replyTo;
    }
    if(comment.serverTime != null) {
      map["serverTime"] = comment.serverTime;
    }
    if(comment.extra != null) {
      map["extra"] = comment.extra;
    }

    return map;
  }

}
