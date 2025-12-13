import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../models/chat_theme_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/chat_theme_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/profile_avatar.dart';
import 'chat_customization_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? contactUser;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.contactUser,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _authService = AuthService();
  final _audioRecorder = FlutterSoundRecorder();
  final _themeService = ChatThemeService();
  bool _isRecording = false;
  bool _showEmojiPicker = false;
  String? _recordingPath;
  final Set<String> _downloadingImages = {}; // Track imágenes en proceso de descarga
  ChatTheme? _chatTheme;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
    _loadChatTheme();
    _loadCurrentUser();
    // Marcar usuario como activo en este chat (await para asegurar que se cree)
    _firestoreService.setUserActiveInChat(widget.currentUserId, widget.chatId).then((_) {
      if (kDebugMode) {
        print('✅ Usuario marcado como activo en chat: ${widget.chatId}');
      }
    }).catchError((error) {
      if (kDebugMode) {
        print('❌ Error al marcar usuario como activo: $error');
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadChatTheme() async {
    final theme = await _themeService.loadChatTheme(widget.chatId);
    if (mounted) {
      setState(() {
        _chatTheme = theme;
      });
    }
  }

  Future<void> _openCustomizationScreen() async {
    final result = await Navigator.of(context).push<ChatTheme>(
      MaterialPageRoute(
        builder: (context) => ChatCustomizationScreen(
          chatId: widget.chatId,
          currentTheme: _chatTheme,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _chatTheme = result;
      });
    }
  }

  @override
  void dispose() {
    // Marcar usuario como inactivo en este chat
    _firestoreService.setUserInactiveInChat(widget.currentUserId, widget.chatId).then((_) {
      if (kDebugMode) {
        print('✅ Usuario marcado como inactivo en chat: ${widget.chatId}');
      }
    }).catchError((error) {
      if (kDebugMode) {
        print('❌ Error al marcar usuario como inactivo: $error');
      }
    });
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _resetUnreadCount() async {
    await _firestoreService.resetUnreadCount(widget.chatId, widget.currentUserId);
  }

  Future<void> _sendTextMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      receiverId: widget.contactUser?.uid ?? '',
      content: _messageController.text.trim(),
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    await _firestoreService.sendMessage(message);
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() {}); // Mostrar indicador de carga

      final imageFile = File(image.path);
      final imageUrl = await _storageService.uploadTemporaryImage(
        imageFile,
        widget.chatId,
      );

      final message = MessageModel(
        id: const Uuid().v4(),
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        receiverId: widget.contactUser?.uid ?? '',
        content: 'Imagen',
        type: MessageType.image,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar imagen: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendAudio() async {
    if (_recordingPath == null) return;

    try {
      setState(() {}); // Mostrar indicador de carga

      final audioFile = File(_recordingPath!);
      
      // Verificar que el archivo existe
      if (!await audioFile.exists()) {
        throw Exception('El archivo de audio no existe');
      }
      
      final audioUrl = await _storageService.uploadTemporaryAudio(
        audioFile,
        widget.chatId,
      );

      final message = MessageModel(
        id: const Uuid().v4(),
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        receiverId: widget.contactUser?.uid ?? '',
        content: 'Audio',
        type: MessageType.audio,
        audioUrl: audioUrl,
        timestamp: DateTime.now(),
      );

      await _firestoreService.sendMessage(message);
      _recordingPath = null;
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar audio: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      // Si ya está grabando, no hacer nada
      if (_isRecording) return;
      
      // Solicitar permisos
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de micrófono denegados')),
          );
        }
        return;
      }

      // Abrir el recorder (si ya está abierto, esto no causará error)
      try {
        await _audioRecorder.openRecorder();
      } catch (e) {
        // Si ya está abierto, continuar
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${appDir.path}/audio_$timestamp.m4a';

      // Iniciar grabación con codec compatible
      await _audioRecorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4, // Cambiar a aacMP4 que es más compatible
      );

      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al grabar: ${e.toString()}')),
        );
      }
      // Asegurarse de cerrar el recorder si hay error
      try {
        await _audioRecorder.closeRecorder();
      } catch (_) {}
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Verificar si está grabando antes de detener
      if (!_isRecording) return;
      
      await _audioRecorder.stopRecorder();
      
      // Cerrar el recorder después de detener
      await _audioRecorder.closeRecorder();
      
      setState(() => _isRecording = false);

      if (_recordingPath != null) {
        await _sendAudio();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al detener grabación: ${e.toString()}')),
        );
      }
      // Asegurarse de cerrar el recorder si hay error
      try {
        await _audioRecorder.closeRecorder();
      } catch (_) {}
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _downloadAndSaveImage(MessageModel message) async {
    // Verificar si ya fue descargada o está en proceso
    if (message.imageUrl == null || 
        message.imageDownloaded || 
        message.localImagePath != null ||
        _downloadingImages.contains(message.id)) {
      return;
    }

    // Marcar como en proceso
    _downloadingImages.add(message.id);

    try {
      final localPath = await _storageService.downloadAndSaveImage(
        message.imageUrl!,
        message.chatId,
        message.id,
      );

      if (localPath != null && mounted) {
        // Marcar como descargada en Firestore y eliminar de la nube si es Base64
        await _firestoreService.markImageAsDownloaded(
          message.chatId,
          message.id,
          message.imageUrl!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen guardada en galería'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar imagen: ${e.toString()}')),
        );
      }
    } finally {
      // Remover del set de descargas en proceso
      _downloadingImages.remove(message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            ProfileAvatar(
              photoUrl: widget.contactUser?.profilePhotoUrl,
              fallbackText: widget.contactUser?.username ?? 'U',
              radius: 20,
            ),
            const SizedBox(width: 12),
            Text(widget.contactUser?.username ?? 'Usuario'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _openCustomizationScreen,
            tooltip: 'Personalizar chat',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            image: _chatTheme?.wallpaperPath != null
                ? DecorationImage(
                    image: FileImage(File(_chatTheme!.wallpaperPath!)),
                    fit: _chatTheme?.wallpaperFit ?? BoxFit.cover,
                  )
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                stream: _firestoreService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay mensajes aún',
                        style: TextStyle(
                          color: _chatTheme?.otherTextColor ?? Colors.black87,
                        ),
                      ),
                    );
                  }

                  final messages = snapshot.data!;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      
                      // Descargar imagen automáticamente solo si es recibida, no descargada y no está en proceso
                      if (!isMe && 
                          message.type == MessageType.image && 
                          !message.imageDownloaded &&
                          !_downloadingImages.contains(message.id)) {
                        // Usar un pequeño delay para evitar múltiples descargas simultáneas
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _downloadAndSaveImage(message);
                          }
                        });
                      }

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        onImageTap: () => _downloadAndSaveImage(message),
                        myBubbleColor: _chatTheme?.myBubbleColor,
                        otherBubbleColor: _chatTheme?.otherBubbleColor,
                        myTextColor: _chatTheme?.myTextColor,
                        otherTextColor: _chatTheme?.otherTextColor,
                        currentUserPhoto: _currentUser?.profilePhotoUrl,
                        currentUsername: _currentUser?.username,
                        contactUserPhoto: widget.contactUser?.profilePhotoUrl,
                        contactUsername: widget.contactUser?.username,
                      );
                    },
                  );
                },
              ),
            ),
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _messageController.text += emoji.emoji;
                    },
                    config: const Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions),
                      onPressed: () {
                        setState(() => _showEmojiPicker = !_showEmojiPicker);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _sendImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    if (_isRecording)
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: _stopRecording,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.mic),
                        onPressed: _startRecording,
                      ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendTextMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

