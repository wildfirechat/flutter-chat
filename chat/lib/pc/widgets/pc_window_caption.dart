import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:chat/theme/app_colors.dart';
import 'hover_builder.dart';

/// Windows 主窗口的自绘标题栏。系统标题栏已在
/// PCWindowManager.setupWindow 中设为 TitleBarStyle.hidden,
/// 由本控件接管:整条可拖动、双击切换最大化,右侧为
/// 最小化/最大化/关闭按钮。关闭走 windowManager.close(),
/// 与系统 X 一致(由 PCWindowManager 的拦截逻辑决定隐藏到托盘或退出)。
///
/// 仅 Windows 使用;macOS 是原生沉浸式标题栏,Linux 保持系统/GTK 标题栏。
class PcWindowCaption extends StatefulWidget {
  /// 是否提供最大化能力(最大化按钮 + 双击标题栏)。
  /// 登录页是固定尺寸小窗,窗口本身已不可缩放,这里也要把入口一并去掉。
  final bool canMaximize;

  const PcWindowCaption({super.key, this.canMaximize = true});

  @override
  State<PcWindowCaption> createState() => _PcWindowCaptionState();
}

class _PcWindowCaptionState extends State<PcWindowCaption> with WindowListener {
  static const double captionHeight = 32;

  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted && value != _isMaximized) {
        setState(() => _isMaximized = value);
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  void _toggleMaximize() async {
    // 不依赖本地缓存的 _isMaximized，防止 maximize/unmaximize 事件漏达后
    // 状态卡死（已最大化却走 maximize() 变成无操作）。
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    // 兜底同步一次真实状态，保证按钮图标正确。
    if (mounted) {
      final current = await windowManager.isMaximized();
      if (mounted && current != _isMaximized) {
        setState(() => _isMaximized = current);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: captionHeight,
      decoration: BoxDecoration(
        // 标题栏与左侧导航栏保持同色
        color: colors.sidebarBgDesktop,
        border: Border(
          bottom: BorderSide(color: colors.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 拖动区:占满按钮以外的全部宽度,双击切换最大化
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: widget.canMaximize ? _toggleMaximize : null,
            ),
          ),
          _CaptionButton(
            icon: Icons.remove,
            onPressed: () => windowManager.minimize(),
          ),
          if (widget.canMaximize)
            _CaptionButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              iconSize: 14,
              onPressed: _toggleMaximize,
            ),
          _CaptionButton(
            icon: Icons.close,
            hoverColor: const Color(0xFFE81123),
            hoverIconColor: Colors.white,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 16,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 46,
          height: _PcWindowCaptionState.captionHeight,
          color: hovered
              ? (hoverColor ?? colors.inputBgHover)
              : Colors.transparent,
          child: Icon(
            icon,
            size: iconSize,
            color: hovered
                ? (hoverIconColor ?? colors.iconPrimary)
                : colors.iconSecondary,
          ),
        ),
      ),
    );
  }
}
