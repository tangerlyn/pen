import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.authorId,
    this.authorNickname = '',
    this.authorLevel = 1,
    required this.imageUrls,
    this.contentBlocks,
    this.title = '',
    this.body = '',
    this.rating = 0.0,

    this.inkIds = const [],
    this.penIds = const [],
    this.likeCount = 0,
    this.scrapCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isLiked = false,
    this.isScrapped = false,
  });

  final String id;
  final String authorId;
  final String authorNickname;
  final int authorLevel;
  final List<String> imageUrls;
  // 블로그 형식 본문 (null이면 기존 body+imageUrls 사용)
  final List<Map<String, dynamic>>? contentBlocks;
  final String title;
  final String body;
  final double rating;

  final List<String> inkIds;
  final List<String> penIds;
  final int likeCount;
  final int scrapCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLiked;
  final bool isScrapped;

  String get thumbnailUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  factory ReviewModel.fromMap(Map<String, dynamic> data, String id) {
    return ReviewModel(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '',
      authorLevel: (data['authorLevel'] as num?)?.toInt() ?? 1,
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      contentBlocks: (data['contentBlocks'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,

      inkIds: List<String>.from(data['inkIds'] as List? ?? []),
      penIds: List<String>.from(data['penIds'] as List? ?? []),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      scrapCount: (data['scrapCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] as DateTime? ?? DateTime.now()),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['updatedAt'] as DateTime?),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorNickname': authorNickname,
        'authorLevel': authorLevel,
        'imageUrls': imageUrls,
        if (contentBlocks != null) 'contentBlocks': contentBlocks,
        'title': title,
        'body': body,
        'rating': rating,

        'inkIds': inkIds,
        'penIds': penIds,
        'likeCount': likeCount,
        'scrapCount': scrapCount,
        'commentCount': commentCount,
        'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  ReviewModel copyWith({
    String? id, String? authorId, String? authorNickname, int? authorLevel, List<String>? imageUrls,
    List<Map<String, dynamic>>? contentBlocks,
    String? title, String? body, double? rating,
    List<String>? inkIds, List<String>? penIds,
    int? likeCount, int? scrapCount, int? commentCount,
    DateTime? createdAt, DateTime? updatedAt, bool? isLiked, bool? isScrapped,
  }) {
    return ReviewModel(
      id: id ?? this.id, authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorLevel: authorLevel ?? this.authorLevel,
      imageUrls: imageUrls ?? this.imageUrls,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      title: title ?? this.title, body: body ?? this.body,
      rating: rating ?? this.rating,
      inkIds: inkIds ?? this.inkIds, penIds: penIds ?? this.penIds,
      likeCount: likeCount ?? this.likeCount,
      scrapCount: scrapCount ?? this.scrapCount, commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLiked: isLiked ?? this.isLiked,
      isScrapped: isScrapped ?? this.isScrapped,
    );
  }
}

class CommentModel {
  const CommentModel({
    required this.id,
    required this.reviewId,
    required this.authorId,
    this.authorNickname = '',
    this.authorLevel = 1,
    this.body,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  final String id;
  final String reviewId;
  final String authorId;
  final String authorNickname;
  final int authorLevel;
  final String? body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  factory CommentModel.fromMap(Map<String, dynamic> data, String id) {
    return CommentModel(
      id: id,
      reviewId: data['reviewId'] as String? ?? '',
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
        'reviewId': reviewId,
        'authorId': authorId,
        'authorNickname': authorNickname,
        'authorLevel': authorLevel,
        if (body != null) 'body': body,
        'createdAt': createdAt,
        'isDeleted': isDeleted,
      };
}
