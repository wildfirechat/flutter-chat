import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局字号档位。索引对应 [_scaleFactors],持久化的是索引而不是倍数,
/// 这样以后调整倍数不会让老用户的选择漂移到别的档位。
class FontSizeViewModel extends ChangeNotifier {
  static const String _fontSizeKey = 'app_font_size_index';

  /// PC 端旧版本用倍数存的 key,只在首次迁移时读一次,不再写入。
  static const String _legacyPcFontScaleKey = 'pc_font_scale';

  static const List<double> _scaleFactors = [0.85, 1.0, 1.15, 1.30, 1.45];
  static const int _defaultIndex = 1;

  int _index = _defaultIndex;

  FontSizeViewModel() {
    _loadFontSizePreference();
  }

  int get index => _index;

  double get textScaleFactor => _scaleFactors[_index];

  int get itemCount => _scaleFactors.length;

  Future<void> _loadFontSizePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_fontSizeKey);
    final int loaded;
    if (stored != null && stored >= 0 && stored < _scaleFactors.length) {
      loaded = stored;
    } else {
      // 迁移:PC 端旧版本把倍数存在 pc_font_scale 里。
      loaded = _findClosestIndex(prefs.getDouble(_legacyPcFontScaleKey) ?? 1.0);
    }
    if (loaded != _index) {
      _index = loaded;
      notifyListeners();
    }
  }

  int _findClosestIndex(double factor) {
    int closestIndex = _defaultIndex;
    double minDiff = double.infinity;
    for (int i = 0; i < _scaleFactors.length; i++) {
      final diff = (factor - _scaleFactors[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  /// 先通知再落盘:滑块拖动时不能等磁盘 IO 返回才回弹。
  void setFontSizeIndex(int index) {
    if (index < 0 || index >= _scaleFactors.length || index == _index) return;
    _index = index;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_fontSizeKey, index));
  }
}
