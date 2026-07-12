import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 与 iOS Share Extension 共享数据：会话列表、应用服务认证信息。
class ShareService {
  static const MethodChannel _channel = MethodChannel('chat.wildfire/share');
  static final ShareService instance = ShareService._internal();

  final _shareItemsController = StreamController<List<ShareItem>>.broadcast();
  bool _initialized = false;

  ShareService._internal();

  Stream<List<ShareItem>> get shareItemsStream => _shareItemsController.stream;

  void init() {
    if (_initialized || !Platform.isIOS) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    _checkPendingItems();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onShareItemsReceived') {
      _emitItems(call.arguments);
    }
  }

  Future<void> _checkPendingItems() async {
    try {
      final items = await _channel.invokeMethod('getPendingShareItems');
      _emitItems(items);
    } catch (e) {
      // 无待处理内容时忽略
    }
  }

  void _emitItems(dynamic raw) {
    if (raw is! List) return;
    final items = raw.map((it) {
      final map = it as Map<dynamic, dynamic>;
      return ShareItem(
        type: map['type'] as String? ?? '',
        value: map['value'] as String? ?? '',
      );
    }).toList();
    if (items.isNotEmpty) {
      _shareItemsController.add(items);
    }
  }

  /// 应用进入后台时调用：把最近会话列表及应用服务认证信息写入 App Group，
  /// 供 iOS Share Extension 读取。
  Future<void> syncSharedDataOnBackground() async {
    if (!Platform.isIOS) return;

    try {
      final conversations = await Imclient.getConversationInfos(
        [ConversationType.Single, ConversationType.Group, ConversationType.Channel],
        [0],
      );

      final sharedConversations = await _buildSharedConversations(conversations);
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('app_server_auth_token');

      await _channel.invokeMethod('saveSharedConversations', {
        'conversations': sharedConversations.map((c) => c.toJson()).toList(),
        'authToken': authToken,
        'appServerAddress': Config.APP_Server_Address,
      });
    } catch (e) {
      debugPrint('syncSharedDataOnBackground error: $e');
    }
  }

  Future<List<SharedConversation>> _buildSharedConversations(
    List<ConversationInfo> conversations,
  ) async {
    final result = <SharedConversation>[];

    for (final info in conversations) {
      final conv = info.conversation;
      String title = '';
      String? portraitUrl;

      try {
        switch (conv.conversationType) {
          case ConversationType.Single:
            final user = await Imclient.getUserInfo(conv.target, refresh: false);
            title = user?.getReadableName() ?? conv.target;
            portraitUrl = user?.portrait;
            break;
          case ConversationType.Group:
            final group = await Imclient.getGroupInfo(conv.target, refresh: false);
            title = group?.name ?? '';
            portraitUrl = group?.portrait;
            break;
          case ConversationType.Channel:
            final channel = await Imclient.getChannelInfo(conv.target, refresh: false);
            title = channel?.name ?? '';
            portraitUrl = channel?.portrait;
            break;
          default:
            continue;
        }
      } catch (e) {
        continue;
      }

      if (title.isEmpty) title = conv.target;

      result.add(SharedConversation(
        type: conv.conversationType.index,
        target: conv.target,
        line: conv.line,
        title: title,
        portraitUrl: portraitUrl ?? '',
      ));
    }

    return result;
  }

  void dispose() {
    _shareItemsController.close();
  }
}

class ShareItem {
  final String type; // text, url, image, file
  final String value;

  const ShareItem({required this.type, required this.value});

  bool get isText => type == 'text';
  bool get isUrl => type == 'url';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
}

class SharedConversation {
  final int type;
  final String target;
  final int line;
  final String title;
  final String portraitUrl;

  const SharedConversation({
    required this.type,
    required this.target,
    required this.line,
    required this.title,
    required this.portraitUrl,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'target': target,
    'line': line,
    'title': title,
    'portraitUrl': portraitUrl,
  };
}
