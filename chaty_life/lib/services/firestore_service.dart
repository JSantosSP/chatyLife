import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/contact_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usuarios
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> updateProfilePhoto(String uid, String photoBase64) async {
    await _firestore.collection('users').doc(uid).update({
      'profilePhotoUrl': photoBase64,
    });
  }

  Future<List<UserModel>> searchUsersByUsername(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: username)
        .where('username', isLessThanOrEqualTo: '$username\uf8ff')
        .limit(10)
        .get();

    return query.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .toList();
  }

  // Contactos
  Future<void> addContact(String userId, String contactId) async {
    final contactDocId = _firestore.collection('contacts').doc().id;
    await _firestore.collection('contacts').doc(contactDocId).set({
      'id': contactDocId,
      'userId': userId,
      'contactId': contactId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<ContactModel>> getContacts(String userId) {
    return _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContactModel.fromMap(doc.data()))
            .toList());
  }

  Future<bool> isContact(String userId, String contactId) async {
    final query = await _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .where('contactId', isEqualTo: contactId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // Chats
  Future<String> createOrGetChat(String userId1, String userId2) async {
    // Ordenar IDs para consistencia
    final participants = [userId1, userId2]..sort();
    final chatId = '${participants[0]}_${participants[1]}';

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'id': chatId,
        'participant1Id': participants[0],
        'participant2Id': participants[1],
        'createdAt': DateTime.now().toIso8601String(),
        'unreadCount1': 0,
        'unreadCount2': 0,
      });
    }

    return chatId;
  }

  Stream<List<ChatModel>> getChats(String userId) {
    // Combinar streams de chats donde el usuario es participant1 o participant2
    final stream1 = _firestore
        .collection('chats')
        .where('participant1Id', isEqualTo: userId)
        .snapshots();

    final stream2 = _firestore
        .collection('chats')
        .where('participant2Id', isEqualTo: userId)
        .snapshots();

    // Combinar ambos streams usando StreamController
    final controller = StreamController<List<ChatModel>>();
    List<ChatModel> chats1 = [];
    List<ChatModel> chats2 = [];
    bool hasData1 = false;
    bool hasData2 = false;

    void emitCombined() {
      if (hasData1 && hasData2) {
        final allChats = [...chats1, ...chats2];
        allChats.sort((a, b) {
          final timeA = a.lastMessageTime ?? a.createdAt;
          final timeB = b.lastMessageTime ?? b.createdAt;
          return timeB.compareTo(timeA);
        });
        if (!controller.isClosed) {
          controller.add(allChats);
        }
      }
    }

    StreamSubscription? subscription1;
    StreamSubscription? subscription2;

    subscription1 = stream1.listen(
      (snapshot) {
        chats1 = snapshot.docs.map((doc) => ChatModel.fromMap(doc.data())).toList();
        hasData1 = true;
        emitCombined();
      },
      onError: (error) {
        if (!controller.isClosed) controller.addError(error);
      },
    );

    subscription2 = stream2.listen(
      (snapshot) {
        chats2 = snapshot.docs.map((doc) => ChatModel.fromMap(doc.data())).toList();
        hasData2 = true;
        emitCombined();
      },
      onError: (error) {
        if (!controller.isClosed) controller.addError(error);
      },
    );

    controller.onCancel = () {
      subscription1?.cancel();
      subscription2?.cancel();
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Stream<ChatModel?> getChat(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? ChatModel.fromMap(doc.data()!) : null);
  }

  Future<void> updateChatLastMessage(String chatId, String message, DateTime timestamp) async {
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': message,
      'lastMessageTime': timestamp.toIso8601String(),
    });
  }

  Future<void> incrementUnreadCount(String chatId, String receiverId) async {
    final chat = await _firestore.collection('chats').doc(chatId).get();
    if (chat.exists) {
      final chatData = ChatModel.fromMap(chat.data()!);
      if (chatData.participant1Id == receiverId) {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount1': FieldValue.increment(1),
        });
      } else {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount2': FieldValue.increment(1),
        });
      }
    }
  }

  Future<void> resetUnreadCount(String chatId, String userId) async {
    final chat = await _firestore.collection('chats').doc(chatId).get();
    if (chat.exists) {
      final chatData = ChatModel.fromMap(chat.data()!);
      if (chatData.participant1Id == userId) {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount1': 0,
        });
      } else {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount2': 0,
        });
      }
    }
  }

  // Mensajes
  Future<void> sendMessage(MessageModel message) async {
    await _firestore
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());

    // Actualizar último mensaje del chat
    await updateChatLastMessage(message.chatId, message.content, message.timestamp);
    
    // Incrementar contador de no leídos
    await incrementUnreadCount(message.chatId, message.receiverId);
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> markMessageAsRead(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  // Marcar imagen como descargada y eliminar de la nube si es Base64
  Future<void> markImageAsDownloaded(String chatId, String messageId, String imageUrl) async {
    final updates = <String, dynamic>{
      'imageDownloaded': true,
    };

    // Si es Base64 (almacenado en Firestore), eliminar la URL para ahorrar espacio
    if (imageUrl.startsWith('data:image')) {
      updates['imageUrl'] = FieldValue.delete(); // Eliminar la imagen Base64 del mensaje
    }
    // Si es ImgBB, mantener la URL pero marcar como descargada

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update(updates);
  }
}

