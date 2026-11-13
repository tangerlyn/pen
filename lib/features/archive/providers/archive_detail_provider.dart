import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';

typedef ArchiveDetailArgs = ({String type, String productId});

// autoDispose — 상세 화면을 닫았다 다시 열면 리뷰 수/평점을 새로 불러온다
// (영구 캐시되면 리뷰를 쓰고 돌아와도 예전 숫자가 계속 보임)
final archiveDetailProvider =
    FutureProvider.autoDispose.family<dynamic, ArchiveDetailArgs>((ref, args) async {
  final repo = ref.read(archiveRepoProvider);
  switch (args.type) {
    case 'ink':
      return repo.getInk(args.productId);
    case 'pen':
      return repo.getPen(args.productId);
    default:
      return null;
  }
});

// 현재 유저가 차단한 uid 목록 — 제품 상세 리뷰에서 차단 유저 리뷰를 빼는 데 사용
final _blockedUidsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(userRepoProvider).watchBlockedUids(uid);
});

final productReviewsProvider = StreamProvider.autoDispose
    .family<List<ReviewModel>, ArchiveDetailArgs>((ref, args) async* {
  final repo = ref.read(reviewRepoProvider);
  final Stream<List<ReviewModel>> stream;
  switch (args.type) {
    case 'ink':
      stream = repo.watchProductReviews(inkId: args.productId);
    case 'pen':
      stream = repo.watchProductReviews(penId: args.productId);
    default:
      return;
  }
  // 차단 목록을 먼저 받아온 뒤 구독해야 차단 유저 리뷰가 잠깐이라도 노출되지 않는다.
  // 차단 목록이 바뀌면 이 provider가 다시 빌드돼 즉시 반영된다.
  final blocked = await ref.watch(_blockedUidsProvider.future);
  if (blocked.isEmpty) {
    yield* stream;
    return;
  }
  yield* stream.map(
    (list) => list.where((r) => !blocked.contains(r.authorId)).toList(),
  );
});
