import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/location_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/recall_notificiation_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/message/ptext_message_content.dart';
import 'package:imclient/message/rich_notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/streaming_text_cancelled_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../search/conversation_search_panel.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/sub_window_app_base.dart';
import '../multi_window/window_event_channel.dart';
import 'search_window_ipc.dart';

/// 会话内搜索窗口的入口 Widget（类似 PC 微信的"聊天记录"窗口）。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，不连接 IM；
/// IM 调用经 [SharedImclientChannel] 转发到主窗口执行，
/// 与朋友圈窗口（MomentWindowApp）同构。
/// 窗口初始化/标题/主题/关窗通知等样板见 [SubWindowAppBase]。
class SearchWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const SearchWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<SearchWindowApp> createState() => _SearchWindowAppState();
}

class _SearchWindowAppState extends State<SearchWindowApp>
    with WindowListener, SubWindowAppBase<SearchWindowApp> {
  late Conversation _conversation;
  String _conversationTitle = '';
  String _keyword = '';

  /// 切换会话时换 key 强制重建面板，清空旧的搜索状态。
  Key _panelKey = UniqueKey();

  // -------------------------------------------------------------- 基类钩子

  @override
  int get windowId => widget.windowId;

  @override
  Map<String, dynamic> get windowArguments => widget.arguments;

  @override
  String get windowKind => kSearchWindowKind;

  @override
  Size get minWindowSize => const Size(480, 600);

  /// 恢复标准标题栏,显示 `"会话名"聊天记录` 标题（对齐 PC 微信）。
  @override
  bool get useNormalTitleBar => true;

  @override
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        SearchWindowEvents.updateConversation: _handleUpdateConversation,
      };

  @override
  String windowTitle(AppLocalizations l10n) =>
      '"$_conversationTitle"${l10n.chatRecords}';

  @override
  Future<void> onWindowReady() async {
    _parseArguments(windowArguments);
  }

  /// 与 Imclient.init 注册的常用类型对齐；未注册的类型解码成
  /// UnknownMessageContent，摘要只会显示"未知消息"。
  @override
  void registerMessageContents() {
    Imclient.registerMessageContent(textContentMeta);
    Imclient.registerMessageContent(imageContentMeta);
    Imclient.registerMessageContent(videoContentMeta);
    Imclient.registerMessageContent(soundContentMeta);
    Imclient.registerMessageContent(fileContentMeta);
    Imclient.registerMessageContent(linkContentMeta);
    Imclient.registerMessageContent(stickerContentMeta);
    Imclient.registerMessageContent(locationMessageContentMeta);
    Imclient.registerMessageContent(cardContentMeta);
    Imclient.registerMessageContent(compositeContentMeta);
    Imclient.registerMessageContent(ptextContentMeta);
    Imclient.registerMessageContent(articlesContentMeta);
    Imclient.registerMessageContent(callStartContentMeta);
    Imclient.registerMessageContent(collectionContentMeta);
    Imclient.registerMessageContent(pollContentMeta);
    Imclient.registerMessageContent(richNotificationContentMeta);
    Imclient.registerMessageContent(recallNotificationContentMeta);
    Imclient.registerMessageContent(tipNotificationContentMeta);
    Imclient.registerMessageContent(streamingTextGeneratingContentMeta);
    Imclient.registerMessageContent(streamingTextGeneratedContentMeta);
    // 流式文本取消消息(20)：Transparent 透传，正常不落库不显示
    Imclient.registerMessageContent(streamingTextCancelledContentMeta);
  }

  @override
  Widget buildHome(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConversationSearchPanel(
          _conversation,
          key: _panelKey,
          initialKeyword: _keyword,
          showSearchHistory: false,
          onLocateMessage: _locateMessage,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- 业务

  void _parseArguments(Map<dynamic, dynamic> args) {
    _conversation = SearchWindowPayload.decodeConversation(args);
    _conversationTitle = SearchWindowPayload.decodeTitle(args);
    _keyword = SearchWindowPayload.decodeKeyword(args);
    _panelKey = _buildPanelKey(_conversation);
  }

  /// 窗口复用时主窗口推来新的搜索目标：整体替换并重建面板状态。
  Future<dynamic> _handleUpdateConversation(dynamic args) async {
    if (args is! Map) return null;
    setState(() {
      _parseArguments(args);
    });
    updateWindowTitle();
    return null;
  }

  Key _buildPanelKey(Conversation conversation) {
    return ValueKey(
        'search-${conversation.conversationType.index}-${conversation.target}-${conversation.line}');
  }

  /// 点击搜索结果：转发给主窗口，由主窗口打开会话并定位消息。
  /// 注意用当前搜索目标会话而不是 message.conversation：桌面端 SDK 返回的
  /// 消息可能不带会话信息，经 IPC 回传后主窗口会拿到空 target 无法定位。
  void _locateMessage(Message message) {
    WindowEventChannel.invoke(0, SearchWindowEvents.locateMessage, {
      'conversation': IpcCodec.encodeConversation(_conversation),
      'messageId': message.messageId,
    });
  }
}
