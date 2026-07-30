import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'moment_config.dart';
import 'visible_scope_page.dart';

/// 朋友圈权限（默认可见范围）的设置与读取。
/// 设置-账户与安全里的「朋友圈权限」入口修改并持久化,
/// 发布动态时作为初始可见范围。
class MomentPermission {
  static const String _modeKey = 'moment_default_scope_mode';
  static const String _usersKey = 'moment_default_scope_users';

  /// 打开朋友圈权限设置页，选择结果持久化为发布默认值。
  static Future<void> openSettingsPage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<VisibleScopeResult>(
      MaterialPageRoute(
        builder: (_) => VisibleScopePage(
          mode: prefs.getInt(_modeKey) ?? 0,
          users: prefs.getStringList(_usersKey) ?? const [],
          onPickUsers: (mode) async {
            final picker = MomentKit.contactPicker;
            final current = prefs.getStringList(_usersKey) ?? const <String>[];
            if (picker == null) return current;
            return picker(context, current);
          },
        ),
      ),
    );
    if (result != null) {
      await prefs.setInt(_modeKey, result.mode);
      await prefs.setStringList(_usersKey, result.users);
    }
  }

  /// 发布页的默认可见范围（未设置时为公开）。
  static Future<({int mode, List<String> users})> loadDefaultScope() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      mode: prefs.getInt(_modeKey) ?? 0,
      users: prefs.getStringList(_usersKey) ?? const <String>[],
    );
  }
}
