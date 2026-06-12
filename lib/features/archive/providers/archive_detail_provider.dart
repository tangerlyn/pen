import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';

typedef ArchiveDetailArgs = ({String type, String productId});

final archiveDetailProvider = FutureProviderFamily<dynamic, ArchiveDetailArgs>((ref, args) async {
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

final productReviewsProvider =
    StreamProviderFamily<List<ReviewModel>, ArchiveDetailArgs>((ref, args) {
  final repo = ref.read(reviewRepoProvider);
  switch (args.type) {
    case 'ink':
      return repo.watchProductReviews(inkId: args.productId);
    case 'pen':
      return repo.watchProductReviews(penId: args.productId);
    default:
      return const Stream.empty();
  }
});
