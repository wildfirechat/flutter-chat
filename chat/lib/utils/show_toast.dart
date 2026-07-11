import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_typography.dart';

/// 全局 NavigatorKey，桌面端自绘 Toast 需要依附其 Overlay。
/// 请在 [MaterialApp] 创建后通过 [setToastNavigatorKey] 注入。
GlobalKey<NavigatorState>? _toastNavigatorKey;

void setToastNavigatorKey(GlobalKey<NavigatorState> key) {
  _toastNavigatorKey = key;
}

/// 跨平台显示 Toast：移动端走 fluttertoast，桌面端使用 Overlay 自绘。
///
/// [msg] 为必填文案；[gravity] 仅对移动端生效，桌面端统一显示在窗口底部。
/// [duration] 为显示时长，默认 2 秒。
void showToast({
  required String msg,
  ToastGravity? gravity,
  Duration duration = const Duration(seconds: 2),
}) {
  if (!isDesktopShell) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: duration.inMilliseconds > 2500 ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
      gravity: gravity ?? ToastGravity.BOTTOM,
    );
    return;
  }

  final overlayState = _toastNavigatorKey?.currentState?.overlay;
  if (overlayState == null || msg.isEmpty) {
    return;
  }

  final entry = OverlayEntry(
    builder: (context) => _DesktopToastWidget(
      message: msg,
      duration: duration,
      onDismissed: () {},
    ),
  );

  overlayState.insert(entry);
  Timer(duration, () {
    entry.remove();
    entry.dispose();
  });
}

class _DesktopToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  const _DesktopToastWidget({
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_DesktopToastWidget> createState() => _DesktopToastWidgetState();
}

class _DesktopToastWidgetState extends State<_DesktopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    Future.delayed(widget.duration - const Duration(milliseconds: 150), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC333333),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: AppText.sm.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
