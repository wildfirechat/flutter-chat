import 'package:flutter/material.dart';
import 'package:momentclient/momentclient.dart';

import '../moment_media_picker.dart';
import 'moment_widgets.dart';

/// 九宫格图片布局（微信朋友圈规则）。
///
/// - 1 张：按原始宽高比缩放（有宽高信息时），限宽不限行数
/// - 2~3 张：1 行 N 列
/// - 4 张：2 行 × 2 列
/// - 5~9 张：3 列多行
class NineGridView extends StatelessWidget {
  final List<FeedEntry> entries;
  final double spacing;
  final void Function(int index)? onTapItem;

  const NineGridView({
    super.key,
    required this.entries,
    this.spacing = 4,
    this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (entries.length == 1) return _single(width);
        return _grid(width);
      },
    );
  }

  Widget _single(double maxWidth) {
    final entry = entries.first;
    final w = entry.mediaWidth ?? 0;
    final h = entry.mediaHeight ?? 0;
    double width;
    double height;
    if (w > 0 && h > 0) {
      width = maxWidth * 0.6;
      if (w < 200) width = maxWidth * 0.5;
      height = width * h / w;
      final maxHeight = maxWidth * 1.2;
      if (height > maxHeight) {
        height = maxHeight;
        width = height * w / h;
      }
    } else {
      width = maxWidth * 0.6;
      height = width * 0.75;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: width, height: height, child: _cell(0, entry)),
    );
  }

  Widget _grid(double maxWidth) {
    final count = entries.length;
    final columns = count <= 3 ? count : 3;
    final cell = (maxWidth - spacing * (columns - 1)) / columns;
    final rows = (count + columns - 1) ~/ columns;
    return Column(
      children: List.generate(rows, (r) {
        return Padding(
          padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : spacing),
          child: Row(
            children: List.generate(columns, (c) {
              final index = r * columns + c;
              if (index >= count) {
                return Expanded(child: SizedBox(height: cell));
              }
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == columns - 1 ? 0 : spacing),
                  child: SizedBox(
                    width: cell,
                    height: cell,
                    child: _cell(index, entries[index]),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _cell(int index, FeedEntry entry) {
    final url = (entry.thumbUrl ?? '').isNotEmpty ? entry.thumbUrl! : entry.mediaUrl;
    final isVideo = momentIsVideoFile(entry.mediaUrl);
    return GestureDetector(
      onTap: () => onTapItem?.call(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MomentNetworkImage(url, fit: BoxFit.cover),
          if (isVideo)
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
            ),
        ],
      ),
    );
  }
}
