import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Theme & text
  ThemeMode _themeMode = ThemeMode.system;
  String _fontFamily = 'Atkinson'; // defined in pubspec fonts
  double _textScale = 1.0; // 0.8..1.4 suggested

  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;
  double get textScale => _textScale;

  Future<void> loadFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final themeStr = sp.getString('themeMode');
    final font = sp.getString('fontFamily');
    final scale = sp.getDouble('textScale');

    if (themeStr != null) {
      _themeMode =
          {
            'light': ThemeMode.light,
            'dark': ThemeMode.dark,
            'system': ThemeMode.system,
          }[themeStr] ??
          ThemeMode.system;
    }
    if (font != null) _fontFamily = font;
    if (scale != null) _textScale = scale.clamp(0.8, 1.6);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      'themeMode',
      {
        ThemeMode.light: 'light',
        ThemeMode.dark: 'dark',
        ThemeMode.system: 'system',
      }[mode]!,
    );
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('fontFamily', family);
    notifyListeners();
  }

  Future<void> setTextScale(double factor) async {
    _textScale = factor.clamp(0.8, 1.6);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('textScale', _textScale);
    notifyListeners();
  }
}
