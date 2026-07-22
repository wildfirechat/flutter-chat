import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';

import '../multi_window/sub_window_manager_base.dart';
import '../multi_window/window_event_channel.dart';
import 'search_window_ipc.dart';

/// 管理 PC 端独立的「会话内搜索」窗口（类似 PC 微信的"聊天记录"窗口）。
///
/// 全局最多一个搜索窗口：已打开时再次进入只切换搜索目标会话并置顶，
/// 不重复开窗。子窗口不连接 IM，数据请求由子窗口经 IPC 转发给主窗口执行
/// （见 MainSearchProxy）。创建序列/ready/closed/close 等样板见
/// [SubWindowManagerBase]。
class SearchWindowManager extends SubWindowManagerBase {
  static final SearchWindowManager instance = SearchWindowManager._internal();

  SearchWindowManager._internal();

  /// 最近一次要求展示的搜索目标；子窗口就绪时若与创建参数不一致会补发更新。
  Conversation? _conversation;
  String _conversationTitle = '';

  @override
  String get windowKind => kSearchWindowKind;

  @override
  SubWindowReusePolicy get reusePolicy => SubWindowReusePolicy.updateContent;

  @override
  Map<String, dynamic> createPayload() =>
      SearchWindowPayload.encode(_conversation!, _conversationTitle);

  @override
  Size initialWindowSize() => const Size(720, 800);

  /// 打开（或切换内容并置顶）搜索窗口。
  Future<void> show({
    required Conversation conversation,
    required String conversationTitle,
  }) async {
    installHandlers();
    _conversation = conversation;
    _conversationTitle = conversationTitle;
    if (await reuseExistingWindow()) return;
    await createAndShow();
  }

  /// 复用已有窗口:未就绪时创建参数仍是旧会话,onSubWindowReady 会补发
  /// 最新内容,这里只在已就绪时发 updateConversation。
  @override
  Future<void> onReuseContent(WindowController controller) async {
    if (windowReady) {
      await WindowEventChannel.invoke(
        controller.windowId,
        SearchWindowEvents.updateConversation,
        SearchWindowPayload.encode(_conversation!, _conversationTitle),
      );
    }
  }

  /// 窗口创建后到就绪前可能又来了新的搜索请求,创建参数已过时,补发最新内容。
  @override
  Future<void> onSubWindowReady(int windowId) async {
    final conversation = _conversation;
    if (conversation != null) {
      await WindowEventChannel.invoke(
        windowId,
        SearchWindowEvents.updateConversation,
        SearchWindowPayload.encode(conversation, _conversationTitle),
      );
    }
  }
}
