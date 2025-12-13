import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chats/chats_screen.dart';
import 'screens/chat/chat_screen.dart';

// Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Flutter maneja automáticamente los insets del sistema por defecto
  // No necesitamos configurar nada adicional
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configurar handler de notificaciones en background
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Inicializar servicio de notificaciones
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatyLife',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0080FF), // Azul eléctrico
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        primaryColor: const Color(0xFF0080FF), // Azul eléctrico
        primarySwatch: MaterialColor(
          0xFF0080FF,
          <int, Color>{
            50: const Color(0xFFE6F2FF),
            100: const Color(0xFFCCE5FF),
            200: const Color(0xFF99CBFF),
            300: const Color(0xFF66B1FF),
            400: const Color(0xFF3397FF),
            500: const Color(0xFF0080FF), // Azul eléctrico principal
            600: const Color(0xFF0066CC),
            700: const Color(0xFF004D99),
            800: const Color(0xFF003366),
            900: const Color(0xFF001A33),
          },
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    // Escuchar notificaciones cuando la app está abierta
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // La notificación se maneja automáticamente por NotificationService
    });

    // Manejar cuando se toca una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Manejar notificación cuando la app se abre desde cerrada
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Actualizar token FCM cuando el usuario inicia sesión
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        final token = await _notificationService.getFCMToken();
        if (token != null) {
          await _firestoreService.updateUser(user.uid, {'fcmToken': token});
        }
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final chatId = message.data['chatId'];
    final senderId = message.data['senderId'];
    
    if (chatId != null && senderId != null) {
      // Navegar al chat cuando se toca la notificación
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            currentUserId: _authService.currentUser?.uid ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const ChatsScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
