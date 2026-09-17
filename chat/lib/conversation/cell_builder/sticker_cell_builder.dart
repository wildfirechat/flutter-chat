import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/sticker/sticker_source.dart';
import 'package:chat/sticker/sticker_view.dart';
import '../../ui_model/ui_message.dart';

class StickerCellBuilder extends PortraitCellBuilder {
  /// 贴纸显示区域边长上限
  static const double _maxSide = 150;

  late final StickerMessageContent stickerContent;
  late final StickerSource? _source;

  StickerCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    stickerContent = model.message.content as StickerMessageContent;
    _source = _resolveSource(stickerContent);
  }

  /// 优先本地(自己发的,临时文件可能已被系统清理),其次远端。
  /// 本地文件存在性在构造时判断一次,避免每次 build 都在主 isolate 同步 stat。
  static StickerSource? _resolveSource(StickerMessageContent content) {
    final localPath = content.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      if (localPath.startsWith('assets/')) {
        return StickerSource.asset(localPath);
      }
      if (File(localPath).existsSync()) {
        return StickerSource.file(localPath);
      }
    }
    final remoteUrl = content.remoteUrl;
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return StickerSource.network(remoteUrl);
    }
    return null;
  }

  /// 贴纸多为透明底(TGS、PNG),像微信/Telegram 一样直接浮在聊天背景上
  @override
  bool get hasBubbleBackground => false;

  @override
  Widget buildMessageContent(BuildContext context) {
    final source = _source;
    if (source == null) {
      return const Icon(Icons.broken_image, size: 64, color: Colors.grey);
    }
    // 宽高已知时先占好位,加载完成前后列表不跳动;未知(老消息)则按内容自适应
    final width = stickerContent.width;
    final height = stickerContent.height;
    final scale =
        width > 0 && height > 0 ? _maxSide / math.max(width, height) : 0.0;
    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: _maxSide, maxHeight: _maxSide),
      child: StickerView(
        source,
        width: scale > 0 ? width * scale : null,
        height: scale > 0 ? height * scale : null,
        decodeSize: (_maxSide * MediaQuery.devicePixelRatioOf(context)).ceil(),
      ),
    );
  }
}
