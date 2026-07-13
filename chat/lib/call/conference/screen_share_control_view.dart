import 'package:flutter/material.dart';
import 'package:avenginekit/engine/call_session.dart';

/// 屏幕共享控制条（占位实现）
/// 桌面端屏幕分享需要 desktop_capturer 或平台通道支持，当前仅保留 UI 占位。
class ScreenShareControlView extends StatelessWidget {
  final CallSession session;
  final VoidCallback onStop;

  const ScreenShareControlView({
    Key? key,
    required this.session,
    required this.onStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.screen_share, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            '正在共享屏幕',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onStop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFA5151),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '停止共享',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
