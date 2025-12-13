import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../widgets/profile_avatar.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../contacts/contacts_screen.dart';
import '../../main.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _themeService = ThemeService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _openChat(ChatModel chat) async {
    if (_currentUser == null) return;

    try {
      final otherUserId = chat.getOtherParticipantId(_currentUser!.uid);
      final contactUser = await _firestoreService.getUser(otherUserId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              contactUser: contactUser,
              currentUserId: _currentUser!.uid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir chat: ${e.toString()}')),
        );
      }
    }
  }

  String _formatLastMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Hoy - mostrar hora
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      // Ayer
      return 'Ayer';
    } else if (difference.inDays < 7) {
      // Esta semana - mostrar día abreviado
      final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return dayNames[dateTime.weekday - 1];
    } else {
      // Más de una semana - mostrar fecha
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: themeNotifier,
            builder: (context, isDarkMode, child) {
              return IconButton(
                icon: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: isDarkMode 
                      ? Colors.amber // Amarillo para luna en modo oscuro
                      : Colors.orange, // Naranja para sol en modo claro
                ),
                onPressed: () async {
                  final newMode = !isDarkMode;
                  await _themeService.saveThemeMode(newMode);
                  themeNotifier.value = newMode;
                },
                tooltip: isDarkMode ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(currentUser: _currentUser),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: StreamBuilder<List<ChatModel>>(
          stream: _firestoreService.getChats(_currentUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              final theme = Theme.of(context);
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay chats aún',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el botón + para buscar contactos',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }

            final chats = snapshot.data!;

            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return FutureBuilder<UserModel?>(
                  future: _firestoreService.getUser(
                    chat.getOtherParticipantId(_currentUser!.uid),
                  ),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const ListTile(
                        leading: CircularProgressIndicator(),
                      );
                    }

                    final contactUser = userSnapshot.data;
                    if (contactUser == null) {
                      return const SizedBox.shrink();
                    }

                    final unreadCount = chat.getUnreadCount(_currentUser!.uid);

                    return ListTile(
                      leading: ProfileAvatar(
                        photoUrl: contactUser.profilePhotoUrl,
                        fallbackText: contactUser.username,
                        radius: 28,
                      ),
                      title: Text(
                        contactUser.username,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        chat.lastMessage ?? 'Sin mensajes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: unreadCount > 0
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatLastMessageTime(chat.lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0080FF), // Azul eléctrico
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _openChat(chat),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ContactsScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF00FF80), // Verde eléctrico
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Buscar contactos',
      ),
    );
  }
}
