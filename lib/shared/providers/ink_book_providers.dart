import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ink_book_model.dart';
import '../../data/models/ink_chart_model.dart';
import '../../data/repositories/ink_book_repository.dart';
import 'providers.dart';

final inkBookRepoProvider = Provider<InkBookRepository>((ref) => InkBookRepository());

final inkBookListProvider = StreamProvider.family<List<InkBookModel>, String>((ref, uid) {
  return ref.watch(inkBookRepoProvider).watchBooks(uid);
});

final inkChartInBookProvider =
    StreamProvider.family<List<InkChartModel>, (String, String)>((ref, args) {
  final (uid, bookId) = args;
  return ref.watch(inkBookRepoProvider).watchChart(uid, bookId);
});

final publicInkBooksProvider = FutureProvider<List<InkBookModel>>((ref) {
  return ref.read(inkBookRepoProvider).getPublicBooks();
});

final userPublicInkBooksProvider = FutureProvider.family<List<InkBookModel>, String>((ref, uid) {
  return ref.read(inkBookRepoProvider).getPublicBooksForUser(uid);
});

/// 뷰어의 팔로우 여부를 반영한 가시적 잉크북 목록
/// - viewerUid == null : 비로그인, 전체 공개만 표시
/// - viewerUid != null && 팔로잉 : 전체 공개 + 팔로워 공개 표시
final userVisibleBooksProvider =
    FutureProvider.family<List<InkBookModel>, (String ownerUid, String? viewerUid)>(
        (ref, args) async {
  final (ownerUid, viewerUid) = args;
  final inkRepo = ref.read(inkBookRepoProvider);

  final publicBooks = await inkRepo.getPublicBooksForUser(ownerUid);

  if (viewerUid != null && viewerUid != ownerUid) {
    final userRepo = ref.read(userRepoProvider);
    final isFollowing = await userRepo.isFollowing(viewerUid, ownerUid);
    if (isFollowing) {
      final followersBooks = await inkRepo.getFollowersOnlyBooksForUser(ownerUid);
      final merged = [...publicBooks];
      for (final b in followersBooks) {
        if (!merged.any((m) => m.id == b.id)) merged.add(b);
      }
      return merged;
    }
  }

  return publicBooks;
});

final inkChartReadonlyProvider =
    FutureProvider.family<List<InkChartModel>, (String, String)>((ref, args) async {
  final (uid, bookId) = args;
  final snap = await ref.read(inkBookRepoProvider).watchChart(uid, bookId).first;
  return snap;
});
