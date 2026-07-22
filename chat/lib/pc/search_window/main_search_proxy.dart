import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_navigator.dart';
import '../call_window/model_codec.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/window_event_channel.dart';
import '../pc_window_manager.dart';
import 'search_window_ipc.dart';

/// 主窗口中的会话内搜索代理。
///
/// 负责：
/// 1. 代搜索子窗口执行 IM 调用（子窗口不连接 IM）。
/// 2. 处理子窗口的「定位消息」请求：主窗口置顶并在右栏打开会话、
///    定位到对应消息。
///
/// 与 [MainMomentProxy] 同构。
class MainSearchProxy {
  static final MainSearchProxy instance = MainSearchProxy._internal();

  MainSearchProxy._internal();

  bool _installed = false;

  /// 安装代理。应在主窗口 [Imclient.init] 完成后调用。
  void install() {
    if (_installed) return;
    _installed = true;

    final channel = WindowEventChannel();
    channel.listen();
    _registerMainWindowHandlers(channel);
  }

  void _registerMainWindowHandlers(WindowEventChannel channel) {
    channel.register(SearchWindowEvents.locateMessage, _handleLocateMessage);
    channel.register(SearchMainEvents.getMessages, _handleGetMessages);
    channel.register(SearchMainEvents.searchMessages, _handleSearchMessages);
    channel.register(SearchMainEvents.getMessagesByTimestamp,
        _handleGetMessagesByTimestamp);
    channel.register(SearchMainEvents.getMessageCountByDay,
        _handleGetMessageCountByDay);
    channel.register(SearchMainEvents.getUserInfo, _handleGetUserInfo);
    channel.register(SearchMainEvents.getConversationFiles,
        _handleGetConversationFiles);
    channel.register(SearchMainEvents.searchFiles, _handleSearchFiles);
    channel.register(SearchMainEvents.getAuthorizedMediaUrl,
        _handleGetAuthorizedMediaUrl);
    channel.register(
        SearchMainEvents.deleteFileRecord, _handleDeleteFileRecord);
  }

  // ------------------------------------------------------------------ 定位消息

  /// 主窗口置顶，并在右栏打开会话、定位到对应消息
  /// （复用通知点击的 windowManager + shell.openConversation 通路）。
  Future<dynamic> _handleLocateMessage(dynamic args) async {
    final conversationMap = args['conversation'] as Map<dynamic, dynamic>?;
    final messageId = args['messageId'] as int?;
    if (conversationMap == null || messageId == null) return null;
    final conversation = IpcCodec.decodeConversation(conversationMap);

    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('MainSearchProxy show/focus main window failed: $e');
    }
    final context = pcWindowNavKey?.currentContext;
    if (context != null && context.mounted) {
      openConversation(context, conversation, toFocusMessageId: messageId);
    }
    return null;
  }

  // ------------------------------------------------------------------ IM 代理

  Future<dynamic> _handleGetMessages(dynamic args) async {
    final conversation = _decodeConversation(args);
    final fromIndex = args['fromIndex'] as int? ?? 0;
    final count = args['count'] as int? ?? 0;
    final contentTypes = (args['contentTypes'] as List?)?.cast<int>();
    final withUser = args['withUser'] as String?;
    final messages = await Imclient.getMessages(conversation, fromIndex, count,
        contentTypes: contentTypes, withUser: withUser);
    return messages.map((e) => IpcCodec.encodeMessage(e)).toList();
  }

  Future<dynamic> _handleSearchMessages(dynamic args) async {
    final conversation = _decodeConversation(args);
    final keyword = args['keyword'] as String? ?? '';
    final order = args['order'] as bool? ?? true;
    final limit = args['limit'] as int? ?? 0;
    final offset = args['offset'] as int? ?? 0;
    final messages =
        await Imclient.searchMessages(conversation, keyword, order, limit, offset);
    return messages.map((e) => IpcCodec.encodeMessage(e)).toList();
  }

  Future<dynamic> _handleGetMessagesByTimestamp(dynamic args) async {
    final conversation = _decodeConversation(args);
    final timestamp = args['timestamp'] as int? ?? 0;
    final count = args['count'] as int? ?? 0;
    final contentTypes = (args['contentTypes'] as List?)?.cast<int>();
    final withUser = args['withUser'] as String?;
    final messages = await Imclient.getMessagesByTimestamp(
        conversation, timestamp, count,
        contentTypes: contentTypes, withUser: withUser);
    return messages.map((e) => IpcCodec.encodeMessage(e)).toList();
  }

  Future<dynamic> _handleGetMessageCountByDay(dynamic args) async {
    final conversation = _decodeConversation(args);
    final startTime = args['startTime'] as int? ?? 0;
    final endTime = args['endTime'] as int? ?? 0;
    final contentTypes = (args['contentTypes'] as List?)?.cast<int>();
    final counts = await Imclient.getMessageCountByDay(
        conversation, startTime, endTime,
        contentTypes: contentTypes);
    return counts;
  }

  Future<dynamic> _handleGetUserInfo(dynamic args) async {
    final userId = args['userId'] as String;
    final groupId = args['groupId'] as String?;
    final refresh = args['refresh'] as bool? ?? false;
    final userInfo =
        await Imclient.getUserInfo(userId, groupId: groupId, refresh: refresh);
    return userInfo != null ? ModelCodec.encodeUserInfo(userInfo) : null;
  }

  Future<dynamic> _handleGetConversationFiles(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.getConversationFiles(
      args['beforeMessageUid'] as int? ?? 0,
      FileRecordOrder.values[args['order'] as int? ?? 0],
      args['count'] as int? ?? 20,
      (files) => completer.complete({
        'errorCode': 0,
        'files': files.map(_encodeFileRecord).toList(),
      }),
      (errorCode) => completer.complete({'errorCode': errorCode}),
      conversation:
          args['conversation'] != null ? _decodeConversation(args) : null,
      fromUser: args['userId'] as String?,
    );
    return completer.future;
  }

  Future<dynamic> _handleSearchFiles(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.searchFiles(
      args['keyword'] as String? ?? '',
      args['beforeMessageUid'] as int? ?? 0,
      FileRecordOrder.values[args['order'] as int? ?? 0],
      args['count'] as int? ?? 20,
      (files) => completer.complete({
        'errorCode': 0,
        'files': files.map(_encodeFileRecord).toList(),
      }),
      (errorCode) => completer.complete({'errorCode': errorCode}),
      conversation:
          args['conversation'] != null ? _decodeConversation(args) : null,
      fromUser: args['userId'] as String?,
    );
    return completer.future;
  }

  Future<dynamic> _handleGetAuthorizedMediaUrl(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.getAuthorizedMediaUrl(
      args['mediaPath'] as String? ?? '',
      args['messageUid'] as int? ?? 0,
      args['mediaType'] as int? ?? 0,
      (url) => completer.complete({'errorCode': 0, 'result': url}),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  Future<dynamic> _handleDeleteFileRecord(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.deleteFileRecord(
      args['messageUid'] as int? ?? 0,
      () => completer.complete({'errorCode': 0}),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  // ------------------------------------------------------------------ 编解码

  Conversation _decodeConversation(dynamic args) {
    return IpcCodec.decodeConversation(
        args['conversation'] as Map<dynamic, dynamic>? ?? const {});
  }

  /// 线格式与 imclient 的 proto map 保持一致，子窗口直接交给
  /// ImclientPlatform 的 _convertProtoFileRecords 解码。
  Map<String, dynamic> _encodeFileRecord(FileRecord record) {
    String url = '';
    try {
      url = record.url;
    } catch (_) {
      // url 为 late 字段，个别记录可能未赋值
    }
    return {
      'conversation': record.conversation != null
          ? IpcCodec.encodeConversation(record.conversation!)
          : null,
      'userId': record.userId,
      'messageUid': record.messageUid,
      'name': record.name,
      'url': url,
      'size': record.size,
      'downloadCount': record.downloadCount,
      'timestamp': record.timestamp,
    };
  }
}
