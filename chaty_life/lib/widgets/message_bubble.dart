import 'dart:convert';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/message_model.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onImageTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onImageTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        // Si es Base64, guardar temporalmente y reproducir
        if (url.startsWith('data:audio')) {
          // Decodificar Base64 y guardar temporalmente
          final base64String = url.split(',')[1];
          final bytes = base64Decode(base64String);
          // Por ahora, usar un enfoque simple con BytesSource
          await _audioPlayer.play(BytesSource(bytes));
        } else {
          await _audioPlayer.play(UrlSource(url));
        }
        setState(() => _isPlaying = true);
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      // Error al reproducir audio
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) ...[
            CircleAvatar(
              radius: 12,
              child: Text(
                widget.message.senderId[0].toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.deepPurple : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message.type == MessageType.text)
                    Text(
                      widget.message.content,
                      style: TextStyle(
                        color: widget.isMe ? Colors.white : Colors.black87,
                      ),
                    )
                  else if (widget.message.type == MessageType.image)
                    GestureDetector(
                      onTap: widget.onImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.message.imageUrl != null
                            ? (widget.message.imageUrl!.startsWith('data:image')
                                ? Image.memory(
                                    // Decodificar Base64
                                    base64Decode(
                                      widget.message.imageUrl!.split(',')[1],
                                    ),
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: widget.message.imageUrl!,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.error,
                                      size: 50,
                                    ),
                                  ))
                            : (widget.message.imageDownloaded
                                ? Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 50,
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )),
                      ),
                    )
                  else if (widget.message.type == MessageType.audio &&
                      widget.message.audioUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: widget.isMe ? Colors.white : Colors.black87,
                          ),
                          onPressed: () => _playAudio(widget.message.audioUrl!),
                        ),
                        const SizedBox(width: 8),
                        const Text('Audio'),
                      ],
                    )
                  else if (widget.message.type == MessageType.emoji)
                    Text(
                      widget.message.content,
                      style: const TextStyle(fontSize: 32),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          widget.message.isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: widget.message.isRead
                              ? Colors.blue
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 12,
              child: Text(
                widget.message.senderId[0].toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

