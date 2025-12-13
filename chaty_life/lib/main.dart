import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/firestore_service.dart';
import 'services/theme_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chats/chats_screen.dart';
import 'screens/chat/chat_screen.dart';

// ValueNotifier global para el tema
final themeNotifier = ValueNotifier<bool>(false);

// Handler para notificaciones en background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Log para debugging
  if (kDebugMode) {
    print("📨 Handling a background message: ${message.messageId}");
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
    print('Message notification: ${message.notification?.body}');
  }
  
  // Aquí puedes procesar el mensaje en segundo plano
  // Por ejemplo, guardar en base de datos local, actualizar contadores, etc.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configurar handler de notificaciones en background (debe ser top-level)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Solicitar permisos de notificación (para iOS y Android 13+)
  final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (kDebugMode) {
    print('🔔 Permisos de notificación: ${settings.authorizationStatus}');
  }

  // Obtener y mostrar el token FCM (para debugging)
  final String? token = await FirebaseMessaging.instance.getToken();
  if (kDebugMode && token != null) {
    print('✅ FCM Token obtenido: ${token.substring(0, 20)}...');
  }

  // Inicializar servicio de notificaciones
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    // Escuchar cambios en el tema
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final isDark = await _themeService.loadThemeMode();
    if (mounted) {
      themeNotifier.value = isDark;
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'ChatyLife',
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
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
      scaffoldBackgroundColor: const Color(0xFFFEEDCE),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0080FF), // Azul eléctrico
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0080FF), // Azul eléctrico
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0080FF), // Azul eléctrico
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      primaryColor: const Color(0xFF0080FF), // Azul eléctrico
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      dividerColor: Colors.grey[800],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF00FF80), // Verde eléctrico
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0080FF), // Azul eléctrico
          foregroundColor: Colors.white,
        ),
      ),
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
    // Manejar notificación cuando la app se abre desde cerrada
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('🚀 App abierta desde notificación: ${initialMessage.data}');
      }
      _handleNotificationTap(initialMessage);
    }

    // Escuchar cambios en el token FCM y actualizar en Firestore
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = _authService.currentUser;
      if (user != null) {
        if (kDebugMode) {
          print('🔄 Actualizando token FCM en Firestore para usuario: ${user.uid}');
        }
        await _firestoreService.updateUser(user.uid, {'fcmToken': newToken});
      }
    });

    // Actualizar token FCM cuando el usuario inicia sesión
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        final token = await _notificationService.getFCMToken();
        if (token != null) {
          if (kDebugMode) {
            print('💾 Guardando token FCM en Firestore para usuario: ${user.uid}');
          }
          await _firestoreService.updateUser(user.uid, {'fcmToken': token});
        }
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final chatId = message.data['chatId'];
    final senderId = message.data['senderId'];
    
    if (kDebugMode) {
      print('👆 Notificación tocada - chatId: $chatId, senderId: $senderId');
    }
    
    if (chatId != null) {
      // Navegar al chat cuando se toca la notificación
      // Usar un pequeño delay para asegurar que el contexto esté disponible
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && context.mounted && _authService.currentUser != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                currentUserId: _authService.currentUser!.uid,
              ),
            ),
          );
        }
      });
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
