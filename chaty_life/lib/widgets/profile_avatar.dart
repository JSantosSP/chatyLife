import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget para mostrar avatar de perfil que puede ser Base64 o URL
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl; // Puede ser Base64 (data:image...) o URL normal
  final String? fallbackText; // Texto a mostrar si no hay foto
  final double radius;
  final double? minRadius;
  final double? maxRadius;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.fallbackText,
    this.radius = 20,
    this.minRadius,
    this.maxRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay foto, mostrar icono de persona o inicial del texto
    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        minRadius: minRadius,
        maxRadius: maxRadius,
        backgroundColor: Colors.grey[300],
        child: fallbackText != null && fallbackText!.isNotEmpty
            ? Icon(
                Icons.person,
                size: radius * 1.2,
                color: Colors.grey[600],
              )
            : Icon(
                Icons.person,
                size: radius * 1.2,
                color: Colors.grey[600],
              ),
      );
    }

    // Si es Base64 (data:image...)
    if (photoUrl!.startsWith('data:image')) {
      try {
        final base64String = photoUrl!.split(',')[1];
        final bytes = base64Decode(base64String);
        return CircleAvatar(
          radius: radius,
          minRadius: minRadius,
          maxRadius: maxRadius,
          backgroundImage: MemoryImage(bytes),
          child: fallbackText != null && fallbackText!.isNotEmpty
              ? null
              : null,
        );
      } catch (e) {
        // Si hay error decodificando Base64, mostrar icono de persona
        return CircleAvatar(
          radius: radius,
          minRadius: minRadius,
          maxRadius: maxRadius,
          backgroundColor: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: radius * 1.2,
            color: Colors.grey[600],
          ),
        );
      }
    }

    // Si es URL normal, usar NetworkImage o CachedNetworkImageProvider
    return CircleAvatar(
      radius: radius,
      minRadius: minRadius,
      maxRadius: maxRadius,
      backgroundImage: NetworkImage(photoUrl!),
      child: fallbackText != null && fallbackText!.isNotEmpty
          ? null
          : null,
    );
  }
}
