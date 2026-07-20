import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'conference_participant_item.dart';
import 'conference_participant_tile.dart';

/// PC 会议演讲者布局:左侧焦点大画面 + 右侧 200px 竖向滚动缩略图条。
/// 对齐 Electron 参考实现;屏幕共享时大画面 contain 适配避免裁剪。
class ConferenceSpeakerLayout extends StatelessWidget {
  /// 焦点用户(大画面),为空时只显示缩略图条。
  final ConferenceParticipantItem? focusItem;

  /// 除焦点外的其他参与者(右侧缩略图条,已排序)。
  final List<ConferenceParticipantItem> others;

  final bool audioOnly;

  final bool Function(ConferenceParticipantItem item) isFocusUser;
  final void Function(ConferenceParticipantItem item) onDoubleTapTile;

  const ConferenceSpeakerLayout({
    Key? key,
    required this.focusItem,
    required this.others,
    required this.audioOnly,
    required this.isFocusUser,
    required this.onDoubleTapTile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final focus = focusItem;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: focus != null
                ? ConferenceParticipantTile(
                    item: focus,
                    audioOnly: audioOnly,
                    isFocus: true,
                    isFocusUser: isFocusUser(focus),
                    fit: focus.isScreenSharing
                        ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                        : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    onDoubleTap: () => onDoubleTapTile(focus),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (others.isNotEmpty)
          SizedBox(
            width: 200,
            child: ListView.builder(
              padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              itemCount: others.length,
              itemBuilder: (context, index) {
                final item = others[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ConferenceParticipantTile(
                      item: item,
                      audioOnly: audioOnly,
                      isFocusUser: isFocusUser(item),
                      onDoubleTap: () => onDoubleTapTile(item),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
