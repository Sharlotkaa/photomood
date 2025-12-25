import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get isDarkMode {
      // You can customize this logic based on your needs
      if (_themeMode == ThemeMode.system) {
        // If using system theme, you might need to check the platform brightness
        // For now, returning false as default
        return false;
      }
      return _themeMode == ThemeMode.dark;
    }
  ThemeService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    final colorValue = prefs.getInt('accent_color') ?? Colors.blue.value;
    
    _themeMode = ThemeMode.values[themeIndex];
    _accentColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
    notifyListeners();
  }
}