import 'package:flutter/material.dart';

class ChatTheme {
  // Colores de fondo de las burbujas
  final Color? myBubbleColor; // Color para mis mensajes
  final Color? otherBubbleColor; // Color para mensajes del otro
  
  // Colores de texto
  final Color? myTextColor; // Color de texto para mis mensajes
  final Color? otherTextColor; // Color de texto para mensajes del otro
  
  // Wallpaper
  final String? wallpaperPath; // Ruta local de la imagen de fondo
  final BoxFit? wallpaperFit; // Cómo ajustar el wallpaper

  const ChatTheme({
    this.myBubbleColor,
    this.otherBubbleColor,
    this.myTextColor,
    this.otherTextColor,
    this.wallpaperPath,
    this.wallpaperFit,
  });

  // Convertir a JSON para guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'myBubbleColor': myBubbleColor?.value,
      'otherBubbleColor': otherBubbleColor?.value,
      'myTextColor': myTextColor?.value,
      'otherTextColor': otherTextColor?.value,
      'wallpaperPath': wallpaperPath,
      'wallpaperFit': wallpaperFit?.index,
    };
  }

  // Crear desde JSON
  factory ChatTheme.fromJson(Map<String, dynamic> json) {
    return ChatTheme(
      myBubbleColor: json['myBubbleColor'] != null
          ? Color(json['myBubbleColor'] as int)
          : null,
      otherBubbleColor: json['otherBubbleColor'] != null
          ? Color(json['otherBubbleColor'] as int)
          : null,
      myTextColor: json['myTextColor'] != null
          ? Color(json['myTextColor'] as int)
          : null,
      otherTextColor: json['otherTextColor'] != null
          ? Color(json['otherTextColor'] as int)
          : null,
      wallpaperPath: json['wallpaperPath'] as String?,
      wallpaperFit: json['wallpaperFit'] != null
          ? BoxFit.values[json['wallpaperFit'] as int]
          : null,
    );
  }

  // Crear una copia con algunos valores modificados
  ChatTheme copyWith({
    Color? myBubbleColor,
    Color? otherBubbleColor,
    Color? myTextColor,
    Color? otherTextColor,
    String? wallpaperPath,
    BoxFit? wallpaperFit,
  }) {
    return ChatTheme(
      myBubbleColor: myBubbleColor ?? this.myBubbleColor,
      otherBubbleColor: otherBubbleColor ?? this.otherBubbleColor,
      myTextColor: myTextColor ?? this.myTextColor,
      otherTextColor: otherTextColor ?? this.otherTextColor,
      wallpaperPath: wallpaperPath ?? this.wallpaperPath,
      wallpaperFit: wallpaperFit ?? this.wallpaperFit,
    );
  }
}
