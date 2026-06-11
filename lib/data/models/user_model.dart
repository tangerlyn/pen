import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/level_system.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.nickname,
    this.profileImageUrl,
    this.bio = '',
    this.interests = const [],
    this.followerCount = 0,
    this.followingCount = 0,
    this.exp = 0,
    required this.loginProvider,
    required this.createdAt,
  });

  final String uid;
  final String nickname;
  final String? profileImageUrl;
  final String bio;
  final List<String> interests;
  final int followerCount;
  final int followingCount;

  /// 누적 경험치 (Firestore: exp)
  final int exp;

  final String loginProvider;
  final DateTime createdAt;

  /// 파생 속성 — Firestore에는 저장하지 않음
  int get level => LevelSystem.levelFromExp(exp);
  double get levelProgress => LevelSystem.progress(exp);
  String get levelProgressLabel => LevelSystem.progressLabel(exp);
  String get levelTitle => LevelSystem.title(level);

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      nickname: data['nickname'] as String? ?? '',
      profileImageUrl: data['profileImageUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      interests: List<String>.from(data['interests'] as List? ?? []),
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      exp: (data['exp'] as num?)?.toInt() ?? 0,
      loginProvider: data['loginProvider'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] as DateTime? ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'bio': bio,
        'interests': interests,
        'followerCount': followerCount,
        'followingCount': followingCount,
        'exp': exp,
        'loginProvider': loginProvider,
        'createdAt': createdAt,
      };

  UserModel copyWith({
    String? uid,
    String? nickname,
    String? profileImageUrl,
    String? bio,
    List<String>? interests,
    int? followerCount,
    int? followingCount,
    int? exp,
    String? loginProvider,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      exp: exp ?? this.exp,
      loginProvider: loginProvider ?? this.loginProvider,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
