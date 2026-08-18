import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/review_model.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';
import 'providers.dart';

final followStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (myUid, targetUid) = args;
  return ref.watch(userRepoProvider).watchFollowStatus(myUid, targetUid);
});

/// 좋아요한 리뷰/게시글 목록 — StreamProvider로 실시간 업데이트
final likedReviewsProvider =
    StreamProvider.family<List<ReviewModel>, String>((ref, uid) {
  return ref.read(reviewRepoProvider).watchLikedReviews(uid);
});

final likedPostsProvider =
    StreamProvider.family<List<PostModel>, String>((ref, uid) {
  return PostRepository().watchLikedPosts(uid);
});
