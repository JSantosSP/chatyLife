import 'dart:io';
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
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/message_bubble.dart';

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
  final _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _showEmojiPicker = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
  }

  @override
  void dispose() {
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

      // Abrir el recorder
      await _audioRecorder.openRecorder();
      
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${appDir.path}/audio_$timestamp.m4a';

      // Iniciar grabación
      await _audioRecorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al grabar: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
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
    if (message.imageUrl == null || message.localImagePath != null) return;

    try {
      final localPath = await _storageService.downloadAndSaveImage(
        message.imageUrl!,
        message.chatId,
        message.id,
      );

      if (localPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen guardada en galería')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.contactUser?.profilePhotoUrl != null
                  ? NetworkImage(widget.contactUser!.profilePhotoUrl!)
                  : null,
              child: widget.contactUser?.profilePhotoUrl == null
                  ? Text(
                      widget.contactUser?.username[0].toUpperCase() ?? 'U',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(widget.contactUser?.username ?? 'Usuario'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _firestoreService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No hay mensajes aún'),
                  );
                }

                final messages = snapshot.data!.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;
                    
                    // Descargar imagen automáticamente si es recibida
                    if (!isMe && message.type == MessageType.image && message.localImagePath == null) {
                      _downloadAndSaveImage(message);
                    }

                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      onImageTap: () => _downloadAndSaveImage(message),
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
    );
  }
}

