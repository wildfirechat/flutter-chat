import 'dart:convert';
import 'dart:math' as math;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';

import '../multi_window/ipc_codec.dart';
import '../multi_window/window_event_channel.dart';
import 'media_preview_ipc.dart';

/// 管理 PC 端独立的媒体预览窗口(参考微信:图片/视频在单独窗口中查看)。
///
/// 全局最多一个预览窗口:已打开时再次预览只替换内容并置顶,不重复开窗。
/// 子窗口不连接 IM,翻页加载更多媒体(loadMore)由本类代查后回传。
class MediaPreviewWindowManager {
  static const String _tag = 'MediaPreviewWindowManager';
  static final MediaPreviewWindowManager instance = MediaPreviewWindowManager._internal();

  MediaPreviewWindowManager._internal();

  WindowController? _windowController;
  bool _windowReady = false;

  /// 窗口创建中又收到的预览请求,只保留最新一次,ready 后补发。
  Map<String, dynamic>? _pendingShow;

  bool _handlersInstalled = false;

  /// 打开媒体预览窗口。
  ///
  /// [mediaItems] 图片/视频消息列表,[defaultIndex] 初始展示第几条。
  /// [conversation] 非空时子窗口翻到两端会继续加载该会话的媒体消息;
  /// 传 null 表示只看给定的几条(引用消息、收藏等场景)。
  Future<void> show({
    required List<Message> mediaItems,
    required int defaultIndex,
    Conversation? conversation,
  }) async {
    _installHandlers();

    final payload = <String, dynamic>{
      'items': MediaPreviewCodec.encodeMessages(mediaItems),
      'defaultIndex': defaultIndex,
      'conversation': conversation != null ? IpcCodec.encodeConversation(conversation) : null,
    };

    final controller = _windowController;
    if (controller != null) {
      if (_windowReady) {
        await WindowEventChannel.invoke(controller.windowId, MediaPreviewEvents.show, payload);
        // 置顶已有窗口
        await controller.show();
      } else {
        _pendingShow = payload;
      }
      return;
    }

    payload[kWindowKindKey] = kMediaPreviewWindowKind;
    final WindowController created;
    try {
      created = await DesktopMultiWindow.createWindow(jsonEncode(payload));
    } catch (e) {
      print('$_tag createWindow failed: $e');
      rethrow;
    }
    _windowController = created;
    _windowReady = false;

    // 与 Call 窗口一致:先定尺寸并显示(子窗口 window_manager 初始化依赖已挂载
    // 的 NSWindow),标题、最小尺寸等样式由子窗口按自身 locale 设置。
    // 必须先 center 再 show:插件创建的 NSWindow 初始位于屏幕原点(macOS 为左下角),
    // 先 show 会在角落闪现一帧后才跳到屏幕中央。
    final size = _initialWindowSize(mediaItems, defaultIndex);
    await created.setFrame(Rect.fromLTWH(0, 0, size.width, size.height));
    await created.center();
    await created.show();
  }

  void _installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    final channel = WindowEventChannel();
    channel.register(MediaPreviewEvents.ready, _handleReady);
    channel.register(MediaPreviewEvents.loadMore, _handleLoadMore);
    channel.register(MediaPreviewEvents.windowClosed, _handleWindowClosed);
    channel.listen();
  }

  Future<dynamic> _handleReady(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId == null || windowId != _windowController?.windowId) return null;
    _windowReady = true;
    final pending = _pendingShow;
    _pendingShow = null;
    if (pending != null) {
      await WindowEventChannel.invoke(windowId, MediaPreviewEvents.show, pending);
    }
    return null;
  }

  /// 子窗口翻页到两端:代查该会话的更多媒体消息(与内嵌预览的翻页语义一致)。
  Future<dynamic> _handleLoadMore(dynamic args) async {
    final conversation = IpcCodec.decodeConversation(args['conversation'] as Map<String, dynamic>);
    final fromMessageId = args['fromMessageId'] as int? ?? 0;
    final tail = args['tail'] as bool? ?? false;
    final messages = await Imclient.getMessages(
      conversation,
      fromMessageId,
      tail ? -10 : 10,
      contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE, MESSAGE_CONTENT_TYPE_VIDEO],
    );
    return MediaPreviewCodec.encodeMessages(messages);
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    // ESC 主动关窗与系统关闭回调会各发一次;快速重开时旧窗口迟到的关闭
    // 事件不能清掉新窗口的状态,按 windowId 过滤
    final windowId = args['windowId'] as int?;
    if (windowId != null &&
        _windowController != null &&
        windowId != _windowController!.windowId) {
      return null;
    }
    _windowController = null;
    _windowReady = false;
    _pendingShow = null;
    return null;
  }

  /// 参考微信:首开时窗口大小随目标图片自适应,并限定在合理范围内。
  Size _initialWindowSize(List<Message> mediaItems, int defaultIndex) {
    const Size minSize = Size(720, 480);
    const Size maxSize = Size(1280, 820);
    double w = 0, h = 0;
    if (defaultIndex >= 0 && defaultIndex < mediaItems.length) {
      final content = mediaItems[defaultIndex].content;
      if (content is ImageMessageContent) {
        w = content.width.toDouble();
        h = content.height.toDouble();
      }
    }
    if (w <= 0 || h <= 0) return const Size(960, 640);
    final double scale = math.min(maxSize.width / w, maxSize.height / h);
    if (scale < 1) {
      w *= scale;
      h *= scale;
    }
    return Size(math.max(w, minSize.width), math.max(h, minSize.height));
  }
}
