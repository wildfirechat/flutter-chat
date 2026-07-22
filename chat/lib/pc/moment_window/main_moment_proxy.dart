import 'dart:async';
import 'dart:typed_data';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart' as mc;
import 'package:imclient/model/conversation.dart';
import 'package:momentclient/moment_comment_content.dart';
import 'package:momentclient/moment_feed_content.dart';

import '../call_window/model_codec.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/proxy_completer.dart';
import '../multi_window/window_event_channel.dart';
import 'moment_ipc.dart';
import 'moment_window_manager.dart';

/// 主窗口中的朋友圈代理。
///
/// 负责：
/// 1. 代朋友圈子窗口执行 IM 调用（子窗口不连接 IM）。
/// 2. 监听 IM 下行消息中的朋友圈消息（Single 会话、line=1），
///    转发刷新信号给朋友圈窗口。
///
/// 与 [MainAvEngineKitProxy] 同构，但朋友圈子窗口只做数据读写，
/// 代理面小得多。
class MainMomentProxy {
  static final MainMomentProxy instance = MainMomentProxy._internal();

  MainMomentProxy._internal();

  StreamSubscription? _receiveMessageSubscription;
  bool _installed = false;

  /// 安装代理。应在主窗口 [Imclient.init] 完成后调用。
  void install() {
    if (_installed) return;
    _installed = true;

    _receiveMessageSubscription =
        Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
      _onReceiveMessages(event.messages);
    });

    final channel = WindowEventChannel();
    channel.listen();
    _registerMainWindowHandlers(channel);
  }

  void uninstall() {
    _receiveMessageSubscription?.cancel();
    _receiveMessageSubscription = null;
    _installed = false;
  }

  // ------------------------------------------------------------------ IM 事件

  void _onReceiveMessages(List<Message> messages) {
    for (final msg in messages) {
      if (msg.conversation.conversationType != ConversationType.Single ||
          msg.conversation.line != 1) {
        continue;
      }
      final content = msg.content;
      final int? feedId;
      if (content is MomentCommentMessageContent) {
        feedId = content.feedId;
      } else if (content is MomentFeedMessageContent) {
        feedId = content.feedId;
      } else {
        continue;
      }
      // 通知朋友圈窗口刷新对应 feed（feedId<=0 时全量刷新）。
      MomentWindowManager.instance
          .notifyFeedChanged(feedId > 0 ? feedId : null);
    }
  }

  // ------------------------------------------------------------------ IM 代理

  void _registerMainWindowHandlers(WindowEventChannel channel) {
    channel.register(
        MomentMainEvents.sendMomentsRequest, _handleSendMomentsRequest);
    channel.register(MomentMainEvents.getUserInfo, _handleGetUserInfo);
    channel.register(MomentMainEvents.getUserInfos, _handleGetUserInfos);
    channel.register(MomentMainEvents.getConversationsMessageByStatus,
        _handleGetConversationsMessageByStatus);
    channel.register(MomentMainEvents.getConversationsUnreadCount,
        _handleGetConversationsUnreadCount);
    channel.register(MomentMainEvents.clearConversationsUnreadStatus,
        _handleClearConversationsUnreadStatus);
    channel.register(MomentMainEvents.uploadMedia, _handleUploadMedia);
    channel.register(
        MomentMainEvents.uploadMediaFile, _handleUploadMediaFile);
    channel.register(MomentMainEvents.serverDeltaTime,
        (_) async => await Imclient.serverDeltaTime);
  }

  Future<dynamic> _handleSendMomentsRequest(dynamic args) async {
    final path = args['path'] as String;
    final data = args['data'] as String? ?? '';
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.sendMomentsRequest(path, data, onSuccess, onFailure));
  }

  Future<dynamic> _handleGetUserInfo(dynamic args) async {
    final userId = args['userId'] as String;
    final refresh = args['refresh'] as bool? ?? false;
    final userInfo = await Imclient.getUserInfo(userId, refresh: refresh);
    return userInfo != null ? ModelCodec.encodeUserInfo(userInfo) : null;
  }

  Future<dynamic> _handleGetUserInfos(dynamic args) async {
    final userIds = (args['userIds'] as List).cast<String>();
    final groupId = args['groupId'] as String?;
    final userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
    return userInfos.map((e) => ModelCodec.encodeUserInfo(e)).toList();
  }

  Future<dynamic> _handleGetConversationsMessageByStatus(dynamic args) async {
    final types = (args['types'] as List)
        .map((e) => ConversationType.values[e as int])
        .toList();
    final lines = (args['lines'] as List).cast<int>();
    final fromIndex = args['fromIndex'] as int? ?? 0;
    final count = args['count'] as int? ?? 100;
    final statuses = (args['messageStatus'] as List? ?? [])
        .map((e) => MessageStatus.values[e as int])
        .toList();
    final withUser = args['withUser'] as String?;
    final messages = await Imclient.getConversationsMessageByStatus(
        types, lines, fromIndex, count, statuses,
        withUser: withUser);
    return messages.map((e) => IpcCodec.encodeMessage(e)).toList();
  }

  Future<dynamic> _handleGetConversationsUnreadCount(dynamic args) async {
    final types = (args['types'] as List)
        .map((e) => ConversationType.values[e as int])
        .toList();
    final lines = (args['lines'] as List).cast<int>();
    final unread = await Imclient.getConversationsUnreadCount(types, lines);
    return {
      'unread': unread.unread,
      'unreadMention': unread.unreadMention,
      'unreadMentionAll': unread.unreadMentionAll,
    };
  }

  Future<dynamic> _handleClearConversationsUnreadStatus(dynamic args) async {
    final types = (args['types'] as List)
        .map((e) => ConversationType.values[e as int])
        .toList();
    final lines = (args['lines'] as List).cast<int>();
    await Imclient.clearConversationsUnreadStatus(types, lines);
    return null;
  }

  Future<dynamic> _handleUploadMedia(dynamic args) async {
    final fileName = args['fileName'] as String? ?? '';
    final mediaData = args['mediaData'];
    final mediaType = mc.MediaType.values[args['mediaType'] as int? ?? 0];
    if (mediaData is! Uint8List) {
      return {'errorCode': -1, 'result': null};
    }
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.uploadMedia(fileName, mediaData, mediaType, onSuccess,
            (current, total) {}, onFailure));
  }

  Future<dynamic> _handleUploadMediaFile(dynamic args) async {
    final filePath = args['filePath'] as String;
    final mediaType = mc.MediaType.values[args['mediaType'] as int? ?? 0];
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.uploadMediaFile(filePath, mediaType, onSuccess,
            (current, total) {}, onFailure));
  }
}
