import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../models/review_model.dart';

class SearchPage<T> {
  const SearchPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

abstract interface class SearchRepository {
  Future<SearchPage<ReviewModel>> fetchReviews({
    required List<String> tokens,
    String? cursor,
    required int limit,
  });

  Future<SearchPage<PostModel>> fetchPosts({
    required List<String> tokens,
    String? cursor,
    required int limit,
  });
}

class FirestoreSearchRepository implements SearchRepository {
  FirestoreSearchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<SearchPage<ReviewModel>> fetchReviews({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) async {
    var query = _firestore
        .collection('reviews')
        .where('searchIndex', arrayContainsAny: tokens)
        .orderBy(FieldPath.documentId)
        .limit(limit + 1);
    if (cursor != null) query = query.startAfter([cursor]);
    final snapshot = await query.get();
    final pageDocs = snapshot.docs.take(limit).toList(growable: false);
    return SearchPage(
      items: pageDocs
          .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
          .toList(growable: false),
      nextCursor: pageDocs.lastOrNull?.id,
      hasMore: snapshot.docs.length > limit,
    );
  }

  @override
  Future<SearchPage<PostModel>> fetchPosts({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) async {
    var query = _firestore
        .collection('posts')
        .where('searchIndex', arrayContainsAny: tokens)
        .orderBy(FieldPath.documentId)
        .limit(limit + 1);
    if (cursor != null) query = query.startAfter([cursor]);
    final snapshot = await query.get();
    final pageDocs = snapshot.docs.take(limit).toList(growable: false);
    return SearchPage(
      items: pageDocs
          .map((doc) => PostModel.fromMap(doc.data(), doc.id))
          .toList(growable: false),
      nextCursor: pageDocs.lastOrNull?.id,
      hasMore: snapshot.docs.length > limit,
    );
  }
}
