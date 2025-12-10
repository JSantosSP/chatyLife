import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Solicitar permisos
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Configurar notificaciones locales
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

      // Obtener token FCM
      final token = await _messaging.getToken();
      if (token != null) {
        // Guardar token en Firestore (se hará desde el servicio de autenticación)
      }

      // Escuchar mensajes en primer plano
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Escuchar cuando se toca una notificación
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Manejar notificación cuando la app está cerrada
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navegar al chat correspondiente
    // Esto se manejará desde el main.dart o un router
    final chatId = message.data['chatId'];
    if (chatId != null) {
      // Navegar al chat
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Manejar tap en notificación local
    final chatId = response.payload;
    if (chatId != null) {
      // Navegar al chat
    }
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



