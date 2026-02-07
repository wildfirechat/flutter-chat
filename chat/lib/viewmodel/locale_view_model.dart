import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleViewModel extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const String _followSystem = 'follow_system';
  
  Locale? _locale;
  String _localeMode = _followSystem; // 'follow_system', 'en', 'zh'

  LocaleViewModel() {
    _loadLocalePreference();
  }

  Locale? get locale => _locale;
  String get localeMode => _localeMode;

  Future<void> _loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _localeMode = prefs.getString(_localeKey) ?? _followSystem;
    _updateLocale();
    notifyListeners();
  }

  void _updateLocale() {
    if (_localeMode == _followSystem) {
      _locale = null; // null means follow system
    } else if (_localeMode == 'en') {
      _locale = const Locale('en', '');
    } else if (_localeMode == 'zh') {
      _locale = const Locale('zh', '');
    }
  }

  Future<void> setLocaleMode(String mode) async {
    _localeMode = mode;
    _updateLocale();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, mode);
    
    notifyListeners();
  }
}
