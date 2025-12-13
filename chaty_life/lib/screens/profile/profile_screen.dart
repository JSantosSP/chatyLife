import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? currentUser;

  const ProfileScreen({super.key, this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  UserModel? _user;
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUserData();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _selectAndUpdatePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Comprimir un poco
        maxWidth: 500, // Redimensionar a máximo 500px
        maxHeight: 500,
      );

      if (image == null) return;

      setState(() => _isUpdatingPhoto = true);

      final imageFile = File(image.path);
      final base64Photo = await _storageService.uploadProfilePhotoAsBase64(imageFile);

      // Actualizar en Firestore
      await _firestoreService.updateProfilePhoto(_user!.uid, base64Photo);

      // Recargar usuario para obtener la foto actualizada
      await _loadUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar foto: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: SafeArea(
        bottom: true, // Respetar el área inferior (botones de navegación)
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            const SizedBox(height: 32),
            Stack(
              children: [
                ProfileAvatar(
                  photoUrl: _user!.profilePhotoUrl,
                  fallbackText: _user!.username,
                  radius: 60,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: _isUpdatingPhoto
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _isUpdatingPhoto ? null : _selectAndUpdatePhoto,
                      tooltip: 'Cambiar foto de perfil',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _user!.username,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _user!.uid,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(_authService.currentUser?.email ?? 'N/A'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Miembro desde'),
                subtitle: Text(
                  '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}',
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}



