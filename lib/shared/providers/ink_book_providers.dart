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
///
/// 팔로우/언팔로우 즉시 반영되도록 watchFollowStatus 스트림을 구독한다.
/// (예전엔 isFollowing()으로 한 번만 조회해서, 팔로우 상태가 바뀌어도
/// 앱을 재시작해야 잉크차트 표시가 갱신됐음)
final userVisibleBooksProvider =
    StreamProvider.family<List<InkBookModel>, (String ownerUid, String? viewerUid)>(
        (ref, args) {
  final (ownerUid, viewerUid) = args;
  final inkRepo = ref.watch(inkBookRepoProvider);

  if (viewerUid == null || viewerUid == ownerUid) {
    return Stream.fromFuture(inkRepo.getPublicBooksForUser(ownerUid));
  }

  final userRepo = ref.watch(userRepoProvider);
  return userRepo.watchFollowStatus(viewerUid, ownerUid).asyncMap((isFollowing) async {
    final publicBooks = await inkRepo.getPublicBooksForUser(ownerUid);
    if (!isFollowing) return publicBooks;

    final followersBooks = await inkRepo.getFollowersOnlyBooksForUser(ownerUid);
    final merged = [...publicBooks];
    for (final b in followersBooks) {
      if (!merged.any((m) => m.id == b.id)) merged.add(b);
    }
    return merged;
  });
});

final inkChartReadonlyProvider =
    FutureProvider.family<List<InkChartModel>, (String, String)>((ref, args) async {
  final (uid, bookId) = args;
  final snap = await ref.read(inkBookRepoProvider).watchChart(uid, bookId).first;
  return snap;
});

/// 단일 잉크북 조회 — 읽기 전용 화면에서 소유자가 설정한 pageStyle/viewMode를 읽어올 때 사용
final singleInkBookProvider =
    FutureProvider.family<InkBookModel?, (String uid, String bookId)>((ref, args) {
  final (uid, bookId) = args;
  return ref.read(inkBookRepoProvider).getBook(uid, bookId);
});
