import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';
  
  // Guardar preferencia de tema
  Future<void> saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }
  
  // Cargar preferencia de tema
  Future<bool> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Por defecto, modo claro (false)
    return prefs.getBool(_themeKey) ?? false;
  }
  
  // Obtener ThemeMode
  Future<ThemeMode> getThemeMode() async {
    final isDark = await loadThemeMode();
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
