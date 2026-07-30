import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imclient/imclient.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_navigator.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/window_event_channel.dart';
import '../pc_window_manager.dart';
import 'search_window_ipc.dart';
import 'search_window_manager.dart';

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

  /// 搜索窗口的 IM 调用已全部由 MainImclientProxy 在共享域 `im.*` 代执行,
  /// 这里只保留「定位消息」这个窗口业务。
  void _registerMainWindowHandlers(WindowEventChannel channel) {
    channel.register(SearchWindowEvents.locateMessage, _handleLocateMessage);
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
    // 对齐 PC 微信：定位后关闭搜索窗口
    await SearchWindowManager.instance.close();
    return null;
  }

}
