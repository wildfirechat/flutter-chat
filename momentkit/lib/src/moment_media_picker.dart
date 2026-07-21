import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

/// 一次媒体选择的结果。
class MomentPickedMedia {
  /// 本地文件路径。
  final String path;

  /// 是否为视频。
  final bool isVideo;

  const MomentPickedMedia(this.path, {this.isVideo = false});
}

/// 相册选择器：返回选中的图片/视频，最多 [maxCount] 个。
typedef MomentMediaPicker = Future<List<MomentPickedMedia>> Function(
  BuildContext context, {
  int maxCount,
});

/// 联系人选择器：返回选中的 userId 列表，[selected] 为已选中项。
typedef MomentContactPicker = Future<List<String>> Function(
  BuildContext context,
  List<String> selected,
);

const Set<String> _kVideoExts = {
  'mp4', 'mov', 'm4v', 'avi', 'mkv', 'flv', 'wmv', '3gp', 'webm',
};

bool _isVideoPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot >= path.length - 1) return false;
  return _kVideoExts.contains(path.substring(dot + 1).toLowerCase());
}

/// 默认媒体选择器：file_picker（移动端系统选择器 / 桌面端文件对话框）。
///
/// 不支持一次混选图片+视频，一次选择内文件类型一致（file_picker 的
/// FileType.media 由系统决定，这里按扩展名区分视频）。
Future<List<MomentPickedMedia>> defaultMomentMediaPicker(
  BuildContext context, {
  int maxCount = 9,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.media,
    allowMultiple: maxCount > 1,
  );
  if (result == null) return const [];
  final picked = <MomentPickedMedia>[];
  for (final f in result.files) {
    final path = f.path;
    if (path == null || path.isEmpty) continue;
    picked.add(MomentPickedMedia(path, isVideo: _isVideoPath(path)));
    if (picked.length >= maxCount) break;
  }
  return picked;
}

/// 判断路径是否像视频文件（发布页九宫格据此展示播放角标）。
bool momentIsVideoFile(String path) => _isVideoPath(path);

/// 读取文件字节（缩略图生成等场景使用）。
Future<List<int>> momentReadFileBytes(String path) {
  return File(path).readAsBytes();
}
