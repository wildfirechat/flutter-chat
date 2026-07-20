import 'package:flutter/material.dart';

import 'conference_participant_item.dart';
import 'conference_participant_tile.dart';

/// 移动端会议焦点页:焦点用户占满全屏,右上角叠加可拖动的预览小窗
/// (通常是自己;双人且焦点是自己时为对方)。双人时点击小窗交换大小画面。
/// 对齐 iOS WFCUConferenceViewController 首页设计。
class ConferenceFocusPage extends StatefulWidget {
  /// 焦点用户(大画面),为空时只显示预览小窗。
  final ConferenceParticipantItem? focusItem;

  /// 预览小窗显示的用户,为 null 或与焦点相同时不显示。
  final ConferenceParticipantItem? previewItem;

  final bool audioOnly;

  /// 双人时点击预览小窗交换焦点。
  final VoidCallback? onSwapPreview;

  final bool Function(ConferenceParticipantItem item) isFocusUser;
  final void Function(ConferenceParticipantItem item)? onDoubleTapTile;

  const ConferenceFocusPage({
    Key? key,
    required this.focusItem,
    required this.previewItem,
    required this.audioOnly,
    required this.isFocusUser,
    this.onSwapPreview,
    this.onDoubleTapTile,
  }) : super(key: key);

  @override
  State<ConferenceFocusPage> createState() => _ConferenceFocusPageState();
}

class _ConferenceFocusPageState extends State<ConferenceFocusPage> {
  static const double _previewWidth = 120;
  static const double _previewHeight = 160; // 3:4
  static const double _margin = 16;

  /// null 表示使用默认位置(右上角)。
  Offset? _previewOffset;

  Offset _initialOffset(Size size) =>
      Offset(size.width - _previewWidth - _margin, _margin);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final offset = _previewOffset ?? _initialOffset(size);
      final focus = widget.focusItem;
      final preview = widget.previewItem;

      return Stack(
        children: [
          Positioned.fill(
            child: focus != null
                ? ConferenceParticipantTile(
                    item: focus,
                    audioOnly: widget.audioOnly,
                    isFocus: true,
                    isFocusUser: widget.isFocusUser(focus),
                    onDoubleTap: widget.onDoubleTapTile != null
                        ? () => widget.onDoubleTapTile!(focus)
                        : null,
                  )
                : const SizedBox.shrink(),
          ),
          if (preview != null && preview != focus)
            Positioned(
              left: offset.dx,
              top: offset.dy,
              width: _previewWidth,
              height: _previewHeight,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final current = _previewOffset ?? _initialOffset(size);
                    final next = current + details.delta;
                    _previewOffset = Offset(
                      next.dx.clamp(_margin, size.width - _previewWidth - _margin),
                      next.dy.clamp(_margin, size.height - _previewHeight - _margin),
                    );
                  });
                },
                onTap: widget.onSwapPreview,
                child: ConferenceParticipantTile(
                  item: preview,
                  audioOnly: widget.audioOnly,
                ),
              ),
            ),
        ],
      );
    });
  }
}
