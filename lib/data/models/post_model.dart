import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.title,
    required this.body,
    this.imageUrls = const [],
    this.contentBlocks,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.category,
  });

  final String id;
  final String authorId;
  final String authorNickname;
  final String title;
  final String body;
  final List<String> imageUrls;
  // 블로그 형식 본문 (null이면 기존 body+imageUrls 사용)
  final List<Map<String, dynamic>>? contentBlocks;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final bool isLiked;
  final String? category;

  factory PostModel.fromMap(Map<String, dynamic> data, String id) {
    return PostModel(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '익명',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      contentBlocks: (data['contentBlocks'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] as DateTime? ?? DateTime.now()),
      category: data['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorNickname': authorNickname,
        'title': title,
        'body': body,
        'imageUrls': imageUrls,
        if (contentBlocks != null) 'contentBlocks': contentBlocks,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'createdAt': FieldValue.serverTimestamp(),
        if (category != null) 'category': category,
      };
}

class PostCommentModel {
  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorNickname,
    this.body,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String? body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  factory PostCommentModel.fromMap(Map<String, dynamic> data, String id) {
    return PostCommentModel(
      id: id,
      postId: data['postId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '익명',
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
        'postId': postId,
        'authorId': authorId,
        'authorNickname': authorNickname,
        if (body != null) 'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': isDeleted,
      };
}
