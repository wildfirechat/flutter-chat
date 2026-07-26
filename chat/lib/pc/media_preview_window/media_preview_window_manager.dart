import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';

import '../multi_window/ipc_codec.dart';
import '../multi_window/sub_window_manager_base.dart';
import '../multi_window/window_event_channel.dart';
import 'media_preview_ipc.dart';

/// 管理 PC 端独立的媒体预览窗口(参考微信:图片/视频在单独窗口中查看)。
///
/// 全局最多一个预览窗口:已打开时再次预览只替换内容并置顶,不重复开窗。
/// 子窗口不连接 IM,翻页加载更多媒体(loadMore)由本类代查后回传。
/// 创建序列/ready/closed 等样板见 [SubWindowManagerBase]。
class MediaPreviewWindowManager extends SubWindowManagerBase {
  static final MediaPreviewWindowManager instance = MediaPreviewWindowManager._internal();

  MediaPreviewWindowManager._internal();

  /// 窗口创建中又收到的预览请求,只保留最新一次,ready 后补发。
  Map<String, dynamic>? _pendingShow;

  /// 下一次创建窗口用的 payload / 首开尺寸(show 时算好,createAndShow 取用)。
  Map<String, dynamic>? _createShowPayload;
  Size _nextInitialSize = const Size(960, 640);

  /// 事件前缀是 'mediaPreview.'(与现网事件名一致)。
  @override
  String get windowKind => 'mediaPreview';

  /// 创建参数 kWindowKindKey 的值是下划线形式,与事件前缀不同。
  @override
  String get creationWindowKind => kMediaPreviewWindowKind;

  /// 预览窗不连 IM,但创建参数仍注入 _selfUserId(基类默认 true),
  /// 供全局水印显示用户 ID(见 WatermarkOverlay 的 Imclient.currentUserId 回退)。

  @override
  SubWindowReusePolicy get reusePolicy => SubWindowReusePolicy.updateContent;

  @override
  Map<String, dynamic> createPayload() => _createShowPayload!;

  @override
  Size initialWindowSize() => _nextInitialSize;

  @override
  Map<String, Future<dynamic> Function(dynamic)> get managerHandlers => {
        MediaPreviewEvents.loadMore: _handleLoadMore,
      };

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
    installHandlers();

    final payload = <String, dynamic>{
      'items': MediaPreviewCodec.encodeMessages(mediaItems),
      'defaultIndex': defaultIndex,
      'conversation': conversation != null ? IpcCodec.encodeConversation(conversation) : null,
    };
    _nextInitialSize = _initialWindowSize(mediaItems, defaultIndex);

    // 窗口可能已被系统关闭按钮销毁(Linux 收不到 windowClosed 事件),
    // 先校验存活,失效时 ensureWindowAlive 会清状态,下面直接走新建。
    final controller = await ensureWindowAlive() ? windowController : null;
    if (controller != null) {
      if (windowReady) {
        await WindowEventChannel.invoke(controller.windowId, MediaPreviewEvents.show, payload);
        // 置顶已有窗口
        await controller.show();
      } else {
        // 创建中的窗口 ready 后由 onSubWindowReady 补发。
        _pendingShow = payload;
      }
      return;
    }

    _createShowPayload = payload;
    await createAndShow();
  }

  /// ready 后补发创建期间收到的最新预览请求。
  @override
  Future<void> onSubWindowReady(int windowId) async {
    final pending = _pendingShow;
    _pendingShow = null;
    if (pending != null) {
      await WindowEventChannel.invoke(windowId, MediaPreviewEvents.show, pending);
    }
  }

  @override
  void onSubWindowClosed() {
    _pendingShow = null;
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
