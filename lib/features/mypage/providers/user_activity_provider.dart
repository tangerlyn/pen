import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../community/providers/community_provider.dart';

final followersProvider = FutureProvider.family<List<UserModel>, String>((ref, uid) async {
  final repo = ref.read(userRepoProvider);
  final uids = await repo.getFollowerUids(uid);
  final users = await Future.wait(uids.map((id) => repo.getUser(id)));
  return users.whereType<UserModel>().toList();
});

final followingListProvider = StreamProvider.family<List<UserModel>, String>((ref, uid) {
  final repo = ref.read(userRepoProvider);
  return repo.watchFollowingUids(uid).asyncMap((uids) async {
    if (uids.isEmpty) return [];
    final users = await Future.wait(uids.map((id) => repo.getUser(id)));
    return users.whereType<UserModel>().toList();
  });
});

final userReviewsProvider = StreamProvider.family<List<ReviewModel>, String>((ref, uid) {
  return ref.watch(reviewRepoProvider).watchUserReviews(uid);
});

final userPostsProvider = StreamProvider.family<List<PostModel>, String>((ref, uid) {
  return ref.watch(postRepositoryProvider).watchUserPosts(uid);
});

final profileUserProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

final blockedUsersDetailProvider = StreamProvider<List<UserModel?>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(userRepoProvider).watchBlockedUids(uid).asyncMap((uids) async {
    if (uids.isEmpty) return [];
    final futures = uids.map((id) => ref.read(userRepoProvider).getUser(id));
    return Future.wait(futures);
  });
});
