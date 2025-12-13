import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Configurar notificaciones locales primero
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos (ya se hace en main.dart, pero por si acaso)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Escuchar cambios en el token FCM
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 Token FCM actualizado: ${newToken.substring(0, 20)}...');
        // El token se actualizará en Firestore desde main.dart
      });

      // Escuchar mensajes en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Notificación recibida en primer plano: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      // Escuchar cuando se toca una notificación (app en background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 Notificación tocada (app en background): ${message.data}');
        _handleNotificationTap(message);
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // La navegación se maneja desde main.dart
    // Este método se puede usar para lógica adicional si es necesario
    if (kDebugMode) {
      print('📱 NotificationService: Notificación tocada - ${message.data}');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Manejar tap en notificación local (mostrada en primer plano)
    final chatId = response.payload;
    if (kDebugMode) {
      print('📱 NotificationService: Notificación local tocada - chatId: $chatId');
    }
    // La navegación se manejará desde main.dart usando el payload
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chaty_life_channel',
      'ChatyLife Notifications',
      channelDescription: 'Notificaciones de mensajes de ChatyLife',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nuevo mensaje',
      message.notification?.body ?? message.data['content'] ?? '',
      details,
      payload: message.data['chatId'],
    );
  }

  Future<String?> getFCMToken() async {
    return await _messaging.getToken();
  }

  Future<void> updateFCMToken(String userId, String token) async {
    // Esto se llamará desde FirestoreService
  }
}



