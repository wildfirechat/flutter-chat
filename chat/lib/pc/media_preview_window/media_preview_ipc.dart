import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/video_message_content.dart';

import '../multi_window/ipc_codec.dart';

// 窗口种类常量已集中到 multi_window/window_kind.dart,此处再导出以兼容
// 现有 import(moment/search 的 manager、main.dart 等均从本文件取这些常量)。
export '../multi_window/window_kind.dart';

/// 主窗口与媒体预览窗口之间的事件名。
class MediaPreviewEvents {
  /// 主窗口 → 预览窗口:窗口已打开时替换为新的媒体列表。
  static const String show = 'mediaPreview.show';

  /// 预览窗口 → 主窗口:窗口已就绪,可以接收 show 事件。
  static const String ready = 'mediaPreview.ready';

  /// 预览窗口 → 主窗口:翻页到列表两端,请求加载更多媒体消息。
  static const String loadMore = 'mediaPreview.loadMore';

  /// 预览窗口 → 主窗口:窗口已关闭。
  static const String windowClosed = 'mediaPreview.windowClosed';
}

/// 媒体预览 IPC 的消息编解码:线格式统一走 [IpcCodec],本类只负责按
/// contentType 实例化图片/视频消息内容类,并裁掉图片预览用不到的缩略图,
/// 避免跨窗口传输大块 base64。
class MediaPreviewCodec {
  static Map<String, dynamic> encodeMessage(Message message) {
    final map = IpcCodec.encodeMessage(message);
    // 预览加载原图,图片缩略图不参与渲染,置空以缩小载荷；
    // 视频的缩略图要留着给 MMVideoPlayer 在原视频加载完成前当封面占位用。
    if (message.content is! VideoMessageContent) {
      (map['content'] as Map<String, dynamic>)['binaryContent'] = null;
    }
    return map;
  }

  static List<Map<String, dynamic>> encodeMessages(List<Message> messages) {
    return messages.map(encodeMessage).toList();
  }

  /// 仅支持图片/视频,其它类型返回 null(由 [decodeMessages] 过滤)。
  static Message? decodeMessage(Map<String, dynamic> map) {
    final contentMap = map['content'] as Map<String, dynamic>?;
    if (contentMap == null) return null;
    final payload = IpcCodec.decodePayload(contentMap);
    final MessageContent content;
    switch (payload.contentType) {
      case MESSAGE_CONTENT_TYPE_IMAGE:
        content = ImageMessageContent();
      case MESSAGE_CONTENT_TYPE_VIDEO:
        content = VideoMessageContent();
      default:
        return null;
    }
    content.decode(payload);

    final message = Message(
      messageId: map['messageId'] as int? ?? 0,
      messageUid: map['messageUid'] as int?,
    );
    final conversationMap = map['conversation'] as Map<String, dynamic>?;
    if (conversationMap != null) {
      message.conversation = IpcCodec.decodeConversation(conversationMap);
    }
    message.fromUser = map['fromUser'] as String? ?? '';
    message.toUsers = (map['toUsers'] as List?)?.cast<String>();
    message.content = content;
    message.direction = MessageDirection.values[map['direction'] as int? ?? 0];
    message.status = MessageStatus.values[map['status'] as int? ?? 0];
    message.serverTime = map['serverTime'] as int? ?? 0;
    message.localExtra = map['localExtra'] as String?;
    return message;
  }

  static List<Message> decodeMessages(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map(decodeMessage)
        .whereType<Message>()
        .toList();
  }
}
