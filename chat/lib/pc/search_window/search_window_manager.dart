import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';

import '../media_preview_window/media_preview_ipc.dart';
import '../multi_window/window_event_channel.dart';
import 'search_window_ipc.dart';

/// 管理 PC 端独立的「会话内搜索」窗口（类似 PC 微信的"聊天记录"窗口）。
///
/// 全局最多一个搜索窗口：已打开时再次进入只切换搜索目标会话并置顶，
/// 不重复开窗。子窗口不连接 IM，数据请求由子窗口经 IPC 转发给主窗口执行
/// （见 MainSearchProxy）。
class SearchWindowManager {
  static const String _tag = 'SearchWindowManager';
  static final SearchWindowManager instance = SearchWindowManager._internal();

  SearchWindowManager._internal();

  WindowController? _windowController;
  bool _windowReady = false;
  bool _handlersInstalled = false;

  /// 最近一次要求展示的搜索目标；子窗口就绪时若与创建参数不一致会补发更新。
  Conversation? _conversation;
  String _conversationTitle = '';

  bool get isReady => _windowController != null && _windowReady;

  /// 打开（或切换内容并置顶）搜索窗口。
  Future<void> show({
    required Conversation conversation,
    required String conversationTitle,
  }) async {
    _installHandlers();

    final controller = _windowController;
    if (controller != null) {
      _conversation = conversation;
      _conversationTitle = conversationTitle;
      try {
        if (_windowReady) {
          await WindowEventChannel.invoke(
            controller.windowId,
            SearchWindowEvents.updateConversation,
            SearchWindowPayload.encode(conversation, conversationTitle),
          );
        }
        // 未就绪时创建参数仍是旧会话：_handleReady 会补发最新内容。
        await controller.show();
      } catch (e) {
        debugPrint('$_tag show existing window failed: $e');
        _windowController = null;
        _windowReady = false;
      }
      if (_windowController != null) return;
    }

    _conversation = conversation;
    _conversationTitle = conversationTitle;
    final payload = <String, dynamic>{
      kWindowKindKey: kSearchWindowKind,
      '_selfUserId': Imclient.currentUserId,
      ...SearchWindowPayload.encode(conversation, conversationTitle),
    };

    final WindowController created;
    try {
      created = await DesktopMultiWindow.createWindow(jsonEncode(payload));
    } catch (e) {
      debugPrint('$_tag createWindow failed: $e');
      rethrow;
    }
    _windowController = created;
    _windowReady = false;

    // 与媒体预览/朋友圈窗口一致：先定尺寸，先 center 再 show，避免窗口在角落闪现。
    await created.setFrame(const Rect.fromLTWH(0, 0, 720, 800));
    await created.center();
    await created.show();
  }

  void _installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    final channel = WindowEventChannel();
    channel.register(SearchWindowEvents.ready, _handleReady);
    channel.register(SearchWindowEvents.windowClosed, _handleWindowClosed);
    channel.listen();
  }

  Future<dynamic> _handleReady(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId == null || windowId != _windowController?.windowId) {
      return null;
    }
    _windowReady = true;
    // 窗口创建后到就绪前可能又来了新的搜索请求，创建参数已过时，补发最新内容。
    final conversation = _conversation;
    if (conversation != null) {
      await WindowEventChannel.invoke(
        windowId,
        SearchWindowEvents.updateConversation,
        SearchWindowPayload.encode(conversation, _conversationTitle),
      );
    }
    return null;
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    // 快速重开时旧窗口迟到的关闭事件不能清掉新窗口的状态，按 windowId 过滤。
    final windowId = args['windowId'] as int?;
    if (windowId != null &&
        _windowController != null &&
        windowId != _windowController!.windowId) {
      return null;
    }
    _windowController = null;
    _windowReady = false;
    return null;
  }
}
