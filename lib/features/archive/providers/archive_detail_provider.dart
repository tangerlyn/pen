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
    FutureProviderFamily<List<ReviewModel>, ArchiveDetailArgs>((ref, args) async {
  final repo = ref.read(reviewRepoProvider);
  switch (args.type) {
    case 'ink':
      final (reviews, _) = await repo.getFeed(inkId: args.productId, limit: 30);
      return reviews;
    case 'pen':
      final (reviews, _) = await repo.getFeed(penId: args.productId, limit: 30);
      return reviews;
    default:
      return [];
  }
});
