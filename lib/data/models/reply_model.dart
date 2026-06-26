import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyModel {
  const ReplyModel({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    this.authorLevel = 1,
    this.body,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String authorId;
  final String authorNickname;
  final int authorLevel;
  final String? body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  factory ReplyModel.fromMap(Map<String, dynamic> data, String id) {
    return ReplyModel(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '',
      authorLevel: (data['authorLevel'] as num?)?.toInt() ?? 1,
      body: data['body'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] as DateTime? ?? DateTime.now()),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorNickname': authorNickname,
        'authorLevel': authorLevel,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      };
}
