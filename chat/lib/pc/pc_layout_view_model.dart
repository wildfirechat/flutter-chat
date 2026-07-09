import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/pc/pc_theme.dart';

/// 桌面端用户可拖拽调整的布局尺寸:中栏宽度、输入栏高度。
/// 与账号无关(登出不重置),拖拽结束时落盘,下次启动恢复。
/// 仅桌面 Shell 在 main.dart 注册;边界值见 [PcTheme]。
class PcLayoutViewModel extends ChangeNotifier {
  static const String _middleColumnWidthKey = 'pc_middle_column_width';
  static const String _inputBarHeightKey = 'pc_input_bar_height';

  double _middleColumnWidth = PcTheme.middleColumnDefaultWidth;
  double _inputBarHeight = PcTheme.inputBarDefaultHeight;

  double get middleColumnWidth => _middleColumnWidth;

  /// 用户期望的输入栏高度。会话区过矮时实际渲染高度还会被压缩,见 PcMessageInputBar。
  double get inputBarHeight => _inputBarHeight;

  /// 在 runApp 之前调用:首帧就用上次的尺寸,避免默认值闪一下再跳。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _middleColumnWidth = clampMiddleColumnWidth(prefs.getDouble(_middleColumnWidthKey) ?? _middleColumnWidth);
      _inputBarHeight = clampInputBarHeight(prefs.getDouble(_inputBarHeightKey) ?? _inputBarHeight);
    } catch (e) {
      debugPrint('load pc layout failed: $e');
    }
  }

  /// 拖拽结束时调用。拖拽过程中每帧写 prefs 没有意义,只在落点持久化。
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_middleColumnWidthKey, _middleColumnWidth);
      await prefs.setDouble(_inputBarHeightKey, _inputBarHeight);
    } catch (e) {
      debugPrint('save pc layout failed: $e');
    }
  }

  void setMiddleColumnWidth(double width) {
    final double clamped = clampMiddleColumnWidth(width);
    if (clamped == _middleColumnWidth) {
      return;
    }
    _middleColumnWidth = clamped;
    notifyListeners();
  }

  void setInputBarHeight(double height) {
    final double clamped = clampInputBarHeight(height);
    if (clamped == _inputBarHeight) {
      return;
    }
    _inputBarHeight = clamped;
    notifyListeners();
  }

  static double clampMiddleColumnWidth(double width) =>
      width.clamp(PcTheme.middleColumnMinWidth, PcTheme.middleColumnMaxWidth).toDouble();

  static double clampInputBarHeight(double height) =>
      height.clamp(PcTheme.inputBarMinHeight, PcTheme.inputBarMaxHeight).toDouble();
}
