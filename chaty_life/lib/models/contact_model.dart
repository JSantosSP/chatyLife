import 'user_model.dart';

class ContactModel {
  final String id;
  final String userId;
  final String contactId;
  final UserModel? contactUser;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.userId,
    required this.contactId,
    this.contactUser,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'contactId': contactId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      contactId: map['contactId'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}



