import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/chat_theme_model.dart';

class ChatThemeService {
  static const String _prefix = 'chat_theme_';

  // Guardar tema de un chat específico
  Future<void> saveChatTheme(String chatId, ChatTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$chatId';
    final json = jsonEncode(theme.toJson());
    await prefs.setString(key, json);
  }

  // Cargar tema de un chat específico
  Future<ChatTheme?> loadChatTheme(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$chatId';
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ChatTheme.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  // Eliminar tema de un chat (restaurar valores por defecto)
  Future<void> deleteChatTheme(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$chatId';
    await prefs.remove(key);
    
    // También eliminar el wallpaper si existe
    final wallpaperKey = '${_prefix}wallpaper_$chatId';
    await prefs.remove(wallpaperKey);
  }

  // Guardar ruta del wallpaper localmente
  Future<void> saveWallpaperPath(String chatId, String wallpaperPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefix}wallpaper_$chatId';
    await prefs.setString(key, wallpaperPath);
  }

  // Cargar ruta del wallpaper
  Future<String?> loadWallpaperPath(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefix}wallpaper_$chatId';
    return prefs.getString(key);
  }
}
