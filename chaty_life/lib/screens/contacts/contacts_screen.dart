import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';
import '../../models/contact_model.dart';
import '../../widgets/profile_avatar.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../main.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  UserModel? _currentUser;
  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _firestoreService.searchUsersByUsername(query);
      if (mounted) {
        setState(() {
          _searchResults = results
              .where((user) => user.uid != _currentUser?.uid)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addContact(String contactId) async {
    if (_currentUser == null) return;

    try {
      final isAlreadyContact = await _firestoreService.isContact(
        _currentUser!.uid,
        contactId,
      );

      if (isAlreadyContact) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este usuario ya es tu contacto')),
          );
        }
        return;
      }

      await _firestoreService.addContact(_currentUser!.uid, contactId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacto agregado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agregar contacto: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openChat(String contactId) async {
    if (_currentUser == null) return;

    try {
      final chatId = await _firestoreService.createOrGetChat(
        _currentUser!.uid,
        contactId,
      );

      if (mounted) {
        final contactUser = await _firestoreService.getUser(contactId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatyLife'),
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
                  final _themeService = ThemeService();
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
        bottom: true, // Respetar el área inferior (botones de navegación)
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar usuarios por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: _isSearching && _searchResults.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildContactsList(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No se encontraron usuarios'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: ProfileAvatar(
            photoUrl: user.profilePhotoUrl,
            fallbackText: user.username,
            radius: 20,
          ),
          title: Text(user.username),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () => _openChat(user.uid),
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () => _addContact(user.uid),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactsList() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<ContactModel>>(
      stream: _firestoreService.getContacts(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No tienes contactos. Busca usuarios para agregar.'),
          );
        }

        final contacts = snapshot.data!;

        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return FutureBuilder<UserModel?>(
              future: _firestoreService.getUser(contact.contactId),
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

                return ListTile(
                  leading: ProfileAvatar(
                    photoUrl: contactUser.profilePhotoUrl,
                    fallbackText: contactUser.username,
                    radius: 20,
                  ),
                  title: Text(contactUser.username),
                  onTap: () => _openChat(contactUser.uid),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            );
          },
        );
      },
    );
  }
}



