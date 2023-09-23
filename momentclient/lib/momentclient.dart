
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';

import 'moment_comment_content.dart';
import 'moment_feed_content.dart';
import 'momentclient_method_channel.dart';

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

typedef PostSuccessCallback = void Function(int feedId, int timestamp);
typedef FeedsSuccessCallback = void Function(List<Feed> feeds);
typedef ProfilesSuccessCallback = void Function(MomentProfiles profiles);
typedef FeedSuccessCallback = void Function(Feed feed);
typedef MomentVoidSuccessCallback = void Function();
typedef FailureCallback = void Function(int errorCode);

class MomentClient {
  ///使用之前必须初始化
  static void init(OnReceiveNewCommentCallback newCommentCallback, OnReceiveMentionedFeedCallback mentionedFeedCallback) {
    MethodChannelMomentClient.instance.init(newCommentCallback, mentionedFeedCallback);
    Imclient.registerMessageContent(commentContentMeta);
    Imclient.registerMessageContent(feedContentMeta);
  }

  ///发布朋友圈
  static Future<Feed> postFeed(WFMContentType type, {String? text, List<FeedEntry>? medias, List<String>? toUsers, List<String>? excludeUsers, List<String>? mentionedUsers, String? extra, void Function(int feedId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    return MethodChannelMomentClient.instance.postFeed(type, text: text, medias: medias, toUsers: toUsers, excludeUsers: excludeUsers, mentionedUsers: mentionedUsers, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///删除朋友圈，朋友圈必须属于当前用户才能删除
  static void deleteFeed(int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    MethodChannelMomentClient.instance.deleteFeed(feedId, successCallback, errorCallback);
  }

  ///批量获取朋友圈
  static void getFeeds(int fromIndex, int count, String? user, FeedsSuccessCallback feedsSuccessCallback, FailureCallback failureCallback) {
    MethodChannelMomentClient.instance.getFeeds(fromIndex, count, user, feedsSuccessCallback, failureCallback);
  }

  ///获取单条朋友圈
  static void getFeed(int feedId, FeedSuccessCallback feedSuccessCallback, FailureCallback failureCallback) {
    MethodChannelMomentClient.instance.getFeed(feedId, feedSuccessCallback, failureCallback);
  }

  ///发布评论或点赞
  static Future<Comment> postComment(WFMCommentType type, int feedId, {int? replyCommentId, String? text, String? replyTo, String? extra, void Function(int commentId, int timestamp)? successCallback, void Function(int errorCode)? errorCallback,}) async {
    return MethodChannelMomentClient.instance.postComment(type, feedId, replyCommentId: replyCommentId, text: text, replyTo: replyTo, extra: extra, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///删除评论或点赞
  static void deleteComment(int commentId, int feedId, MomentVoidSuccessCallback successCallback, FailureCallback errorCallback) {
    MethodChannelMomentClient.instance.deleteComment(commentId, feedId, successCallback, errorCallback);
  }

  ///获取评论或提醒消息
  static Future<List<Message>> getMessages(int fromIndex, bool isNew) async {
    return MethodChannelMomentClient.instance.getMessages(fromIndex, isNew);
  }

  ///获取朋友圈消息未读数量
  static Future<int> getUnreadCount() async {
    return MethodChannelMomentClient.instance.getUnreadCount();
  }

  ///清除朋友圈消息未读数量
  static Future<void> clearUnreadStatus() async {
    return MethodChannelMomentClient.instance.clearUnreadStatus();
  }

  ///为用户缓存数据
  static Future<void> storeCache(List<Feed> feeds, {String? userId}) async {
    return MethodChannelMomentClient.instance.storeCache(feeds, userId);
  }

  ///获取缓存的数据
  static Future<List<Feed>> restoreCache({String? userId}) async {
    return MethodChannelMomentClient.instance.restoreCache(userId: userId);
  }

  ///获取朋友圈设置
  static void getUserProfile(ProfilesSuccessCallback successCallback, FailureCallback failureCallback, {String? userId}) {
    MethodChannelMomentClient.instance.getUserProfile(userId, successCallback, failureCallback);
  }

  ///更新朋友圈设置
  static void updateMyProfile(WFMUpdateUserProfileType updateProfileType, String? strValue, int? intValue, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    MethodChannelMomentClient.instance.updateMyProfile(updateProfileType, strValue, intValue, successCallback, failureCallback);
  }

  ///更新block和black的列表
  static void updateBlackOrBlockList(bool isBlock, List<String>? addList, List<String>? removeList, MomentVoidSuccessCallback successCallback, FailureCallback failureCallback) {
    MethodChannelMomentClient.instance.updateBlackOrBlockList(isBlock, addList, removeList, successCallback, failureCallback);
  }

  ///记录最后阅读时间
  static Future<void> updateLastReadTimestamp() async {
    return MethodChannelMomentClient.instance.updateLastReadTimestamp();
  }

  ///获取最后阅读时间
  static Future<int> getLastReadTimestamp() async {
    return MethodChannelMomentClient.instance.getLastReadTimestamp();
  }
}
