import 'dart:async';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:moment/client/moment_comment_content.dart';
import 'package:moment/client/moment_feed_content.dart';

import '../multi_window/window_event_channel.dart';
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

    // 仍需 listen:朋友圈窗口的 ready/windowClosed 由 MomentWindowManager 注册。
    WindowEventChannel().listen();
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

  /// 朋友圈窗口的 IM 调用已全部由 MainImclientProxy 在共享域 `im.*` 代执行,
  /// 这里不再注册任何 IM handler,只保留 feed 刷新广播(见 [_onReceiveMessages])。
}
