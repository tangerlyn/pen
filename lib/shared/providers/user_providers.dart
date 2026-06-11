import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/review_model.dart';
import 'providers.dart';

final followStatusProvider =
    StreamProvider.family<bool, (String, String)>((ref, args) {
  final (myUid, targetUid) = args;
  return ref.watch(userRepoProvider).watchFollowStatus(myUid, targetUid);
});

/// 스크랩 목록 (여러 곳에서 invalidate할 수 있도록 전역 배치)
final scrappedReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, uid) {
  return ref.read(reviewRepoProvider).getScrappedReviews(uid);
});
