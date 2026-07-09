import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局明暗主题。持久化的是 'system' / 'light' / 'dark' 三个稳定字符串,
/// 不存 [ThemeMode.index] —— 枚举里插一项就会让老用户的选择漂移。
class ThemeViewModel extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';

  /// PC 端旧版本写过但从没被读取的 key,只在首次迁移时读一次,不再写入。
  static const String _legacyPcThemeModeKey = 'pc_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// 在 runApp 之前 await,否则暗色用户开屏会先闪一帧浅色。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey) ?? prefs.getString(_legacyPcThemeModeKey);
    final loaded = _parse(stored);
    if (loaded != _themeMode) {
      _themeMode = loaded;
      notifyListeners();
    }
  }

  /// 先通知再落盘:切换主题不能等磁盘 IO 返回才重绘。
  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_themeModeKey, _serialize(mode)));
  }

  /// 兼容旧的 'follow_system';认不出来的一律回落到跟随系统。
  static ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
