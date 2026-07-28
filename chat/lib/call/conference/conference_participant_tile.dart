import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/portrait.dart';

import 'conference_participant_item.dart';

/// 会议参与者视频 tile:视频画面(无视频时头像渐变底)、说话绿框、
/// 焦点黄框、左下角名字与静音/观众状态、左上角焦点标、右上角说话指示。
/// 移动端网格/焦点页与 PC 宫格/演讲者布局共用。
class ConferenceParticipantTile extends StatelessWidget {
  final ConferenceParticipantItem item;

  /// 会议为纯音频模式时不渲染视频画面。
  final bool audioOnly;

  /// 大画面(焦点页/演讲者主画面),头像与元素更大。
  final bool isFocus;

  /// 是否焦点用户(黄框 + 左上角高亮标)。
  final bool isFocusUser;

  /// 视频填充方式,屏幕共享大画面时应传 contain 避免裁剪。
  final RTCVideoViewObjectFit fit;

  final VoidCallback? onDoubleTap;

  const ConferenceParticipantTile({
    Key? key,
    required this.item,
    this.audioOnly = false,
    this.isFocus = false,
    this.isFocusUser = false,
    this.fit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    this.onDoubleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isSelf = item.userId == Imclient.currentUserId;
    bool showVideo = !audioOnly && !item.videoMuted && item.renderer.srcObject != null;

    // 说话指示(绿框/角标)由 item.speakingNotifier 驱动局部刷新,
    // 音量高频上报时不再随整页 setState 重建 RTCVideoView。
    return ValueListenableBuilder<bool>(
      valueListenable: item.speakingNotifier,
      builder: (context, isSpeaking, child) {
        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: isSpeaking || isFocusUser
                  ? Border.all(
                      color: isFocusUser ? context.colors.warning : context.colors.success,
                      width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (showVideo)
                    RTCVideoView(
                      item.renderer,
                      objectFit: fit,
                      mirror: isSelf,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [context.colors.surface, context.colors.primaryBackground],
                        ),
                      ),
                      child: Center(
                        child: Portrait(
                          item.userInfo?.portrait ?? '',
                          Config.defaultUserPortrait,
                          width: isFocus ? 96 : 64,
                          height: isFocus ? 96 : 64,
                          borderRadius: isFocus ? 48 : 32,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.audioMuted)
                          Icon(Icons.mic_off, color: context.colors.textSecondary, size: 16),
                        if (item.isAudience)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(AppLocalizations.of(context)!.conferenceAudience,
                                style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                          ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isSelf ? AppLocalizations.of(context)!.meLabel : (item.userInfo?.getReadableName() ?? ''),
                            style: AppText.sm.copyWith(color: context.colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFocusUser)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(Icons.highlight, color: context.colors.warning, size: 20),
                    ),
                  if (isSpeaking)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.colors.success.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.volume_up, color: context.colors.textPrimary, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
