import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/review_model.dart';
import '../models/reply_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_system.dart';
import '../../core/utils/search_utils.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app());
  
  CollectionReference get _reviews => _firestore.collection(AppConstants.reviewsCol);

  Future<(List<ReviewModel>, Object?)> getFeed({
    String? filterCategory,
    String? inkId,
    String? penId,
    Object? lastDoc,
    int limit = 20,
  }) async {
    Query query = _reviews.orderBy('createdAt', descending: true);

    if (filterCategory != null && filterCategory != '전체') {
      query = query.where('categories', arrayContains: filterCategory);
    } else {
      if (inkId != null) query = query.where('inkIds', arrayContains: inkId);
      else if (penId != null) query = query.where('penIds', arrayContains: penId);
    }

    query = query.limit(limit);

    if (lastDoc != null && lastDoc is DocumentSnapshot) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    
    final reviews = snapshot.docs.map((doc) {
      return ReviewModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    final nextLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return (reviews, nextLastDoc);
  }

  Future<(List<ReviewModel>, Object?)> getFollowingFeed({
    required List<String> followingUids,
    Object? lastDoc,
    int limit = 20,
  }) async {
    if (followingUids.isEmpty) return (<ReviewModel>[], null);

    final chunks = [
      for (var i = 0; i < followingUids.length; i += 30)
        followingUids.sublist(i, (i + 30).clamp(0, followingUids.length))
    ];

    // 팔로잉 30명 이하: cursor-based 페이지네이션 정상 지원
    if (chunks.length == 1) {
      Query query = _reviews
          .where('authorId', whereIn: chunks.first)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (lastDoc is DocumentSnapshot) {
        query = query.startAfterDocument(lastDoc);
      }
      final snap = await query.get();
      final reviews = snap.docs
          .map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      return (reviews, snap.docs.isNotEmpty ? snap.docs.last : null);
    }

    // 팔로잉 31명 이상: 각 청크 병렬 조회 후 in-memory 병합 (1페이지만 지원)
    if (lastDoc != null) return (<ReviewModel>[], null);
    final snapshots = await Future.wait(
      chunks.map((chunk) => _reviews
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()),
    );
    final allReviews = snapshots
        .expand((s) => s.docs.map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (allReviews.take(limit).toList(), null);
  }

  Future<bool> hasNewFollowingReview({
    required List<String> followingUids,
    required DateTime since,
  }) async {
    if (followingUids.isEmpty) return false;
    final chunks = [
      for (var i = 0; i < followingUids.length; i += 30)
        followingUids.sublist(i, (i + 30).clamp(0, followingUids.length))
    ];
    final snapshots = await Future.wait(
      chunks.map((chunk) => _reviews
          .where('authorId', whereIn: chunk)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .limit(1)
          .get()),
    );
    return snapshots.any((s) => s.docs.isNotEmpty);
  }

  Future<ReviewModel?> getReview(String reviewId) async {
    final doc = await _reviews.doc(reviewId).get();
    if (!doc.exists) return null;
    return ReviewModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> createReview(ReviewModel review) async {
    // id가 빈 문자열이면 새로 생성, 지정되어 있으면 doc(id)로 생성
    final docRef = review.id.isNotEmpty ? _reviews.doc(review.id) : _reviews.doc();
    
    final reviewData = review.toMap();
    // timestamp 형변환
    reviewData['createdAt'] = Timestamp.fromDate(review.createdAt);

    final categories = <String>[];
    if (review.inkIds.isNotEmpty) categories.add('잉크');
    if (review.penIds.isNotEmpty) categories.add('만년필');
    reviewData['categories'] = categories;

    reviewData['searchIndex'] = SearchUtils.buildIndex(review.title, review.body);

    await docRef.set(reviewData);
    return docRef.id;
  }

  Future<void> deleteReview(String reviewId, ReviewModel review) async {
    await _reviews.doc(reviewId).delete();
  }

  Future<void> updateReview(String reviewId, Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    if (title.isNotEmpty || body.isNotEmpty) {
      data['searchIndex'] = SearchUtils.buildIndex(title, body);
    }
    await _reviews.doc(reviewId).update(data);
  }

  Future<void> toggleLike(String reviewId, String uid, bool isLiked) async {
    final likeRef = _reviews.doc(reviewId).collection('likes').doc(uid);
    final reviewRef = _reviews.doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final reviewDoc = await transaction.get(reviewRef);
      if (!reviewDoc.exists) throw Exception('Review not found');

      final likeDoc = await transaction.get(likeRef);
      final data = reviewDoc.data() as Map<String, dynamic>?;
      final currentLikeCount = data?['likeCount'] as num? ?? 0;

      if (isLiked) {
        if (!likeDoc.exists) {
          transaction.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
          transaction.update(reviewRef, {'likeCount': currentLikeCount + 1});
          // 작성자에게 좋아요 EXP 지급
          final authorId = data?['authorId'] as String?;
          if (authorId != null) {
            transaction.update(
              _firestore.collection('users').doc(authorId),
              {'exp': FieldValue.increment(LevelSystem.expLike)},
            );
          }
        }
      } else {
        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(reviewRef, {'likeCount': currentLikeCount > 0 ? currentLikeCount - 1 : 0});
        }
      }
    });
  }

  Future<bool> isLiked(String reviewId, String uid) async {
    final likeDoc = await _reviews.doc(reviewId).collection('likes').doc(uid).get();
    return likeDoc.exists;
  }

  Future<void> toggleScrap(String reviewId, String uid, bool isScrapped) async {
    final scrapRef = _reviews.doc(reviewId).collection('scraps').doc(uid);
    final reviewRef = _reviews.doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final reviewDoc = await transaction.get(reviewRef);
      if (!reviewDoc.exists) throw Exception('Review not found');

      final scrapDoc = await transaction.get(scrapRef);
      final scrapData = reviewDoc.data() as Map<String, dynamic>?;
      final currentScrapCount = scrapData?['scrapCount'] as num? ?? 0;

      if (isScrapped) {
        if (!scrapDoc.exists) {
          transaction.set(scrapRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
          transaction.update(reviewRef, {'scrapCount': currentScrapCount + 1});
        }
      } else {
        if (scrapDoc.exists) {
          transaction.delete(scrapRef);
          transaction.update(reviewRef, {'scrapCount': currentScrapCount > 0 ? currentScrapCount - 1 : 0});
        }
      }
    });
  }

  Future<bool> isScrapped(String reviewId, String uid) async {
    final scrapDoc = await _reviews.doc(reviewId).collection('scraps').doc(uid).get();
    return scrapDoc.exists;
  }

  Future<List<ReviewModel>> getScrappedReviews(String uid) async {
    final querySnapshot = await _firestore
        .collectionGroup('scraps')
        .where('uid', isEqualTo: uid)
        .get();

    final futures = querySnapshot.docs
        .where((doc) => doc.reference.parent.parent?.parent.id == 'reviews')
        .map((doc) async {
      final reviewRef = doc.reference.parent.parent!;
      final reviewDoc = await reviewRef.get();
      if (!reviewDoc.exists) return null;
      return ReviewModel.fromMap(reviewDoc.data() as Map<String, dynamic>, reviewDoc.id);
    });

    return (await Future.wait(futures)).whereType<ReviewModel>().toList();
  }

  Stream<List<ReviewModel>> watchScrappedReviews(String uid) {
    return _firestore
        .collectionGroup('scraps')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) async {
          final futures = snap.docs
              .where((doc) => doc.reference.parent.parent?.parent.id == 'reviews')
              .map((doc) async {
            final reviewRef = doc.reference.parent.parent!;
            final reviewDoc = await reviewRef.get();
            if (!reviewDoc.exists) return null;
            return ReviewModel.fromMap(
                reviewDoc.data() as Map<String, dynamic>, reviewDoc.id);
          });
          return (await Future.wait(futures)).whereType<ReviewModel>().toList();
        });
  }

  Stream<List<CommentModel>> watchComments(String reviewId) {
    return _reviews.doc(reviewId).collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CommentModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addComment(String reviewId, CommentModel comment) async {
    final commentRef = _reviews.doc(reviewId).collection('comments').doc(comment.id.isNotEmpty ? comment.id : null);
    final reviewRef = _reviews.doc(reviewId);
    
    final commentData = comment.toMap();
    commentData['createdAt'] = Timestamp.fromDate(comment.createdAt);

    final batch = _firestore.batch();
    batch.set(commentRef, commentData);
    batch.update(reviewRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String reviewId, String commentId) async {
    final commentRef = _reviews.doc(reviewId).collection('comments').doc(commentId);
    final reviewRef = _reviews.doc(reviewId);

    final repliesSnap = await commentRef.collection('replies').limit(1).get();
    final batch = _firestore.batch();
    if (repliesSnap.docs.isEmpty) {
      batch.delete(commentRef);
    } else {
      batch.update(commentRef, {'isDeleted': true, 'body': FieldValue.delete()});
    }
    batch.update(reviewRef, {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> updateComment(String reviewId, String commentId, String body) async {
    await _reviews.doc(reviewId).collection('comments').doc(commentId)
        .update({'body': body, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<List<ReplyModel>> watchReplies(String reviewId, String commentId) {
    return _reviews
        .doc(reviewId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => ReplyModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addReply(String reviewId, String commentId, ReplyModel reply) async {
    final replyRef = _reviews
        .doc(reviewId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc();
    final batch = _firestore.batch();
    batch.set(replyRef, reply.toMap());
    batch.update(_reviews.doc(reviewId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteReply(String reviewId, String commentId, String replyId) async {
    final replyRef = _reviews
        .doc(reviewId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);
    final batch = _firestore.batch();
    batch.delete(replyRef);
    batch.update(_reviews.doc(reviewId), {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> updateReply(
      String reviewId, String commentId, String replyId, String body) async {
    await _reviews
        .doc(reviewId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .update({'body': body, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> report(String reviewId, String reporterId, String reason) async {
    await _firestore.collection(AppConstants.reportsCol).add({
      'targetType': 'review',
      'targetId': reviewId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ReviewModel>> watchUserReviews(String uid) {
    return _reviews
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Stream<List<ReviewModel>> watchProductReviews({String? inkId, String? penId, int limit = 30}) {
    Query query = _reviews.orderBy('createdAt', descending: true);
    if (inkId != null) {
      query = query.where('inkIds', arrayContains: inkId);
    } else if (penId != null) {
      query = query.where('penIds', arrayContains: penId);
    }
    return query.limit(limit).snapshots()
        .map((s) => s.docs.map((d) => ReviewModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // ── 제품별 실시간 통계 (리뷰 개수, 평균 별점) ────────────────
  Future<(int reviewCount, double avgRating)> getProductStats(String type, String productId) async {
    final queryField = '${type}Ids';
    final baseQuery = _reviews.where(queryField, arrayContains: productId);

    // count()는 단일 필드 인덱스로 동작 (복합 인덱스 불필요)
    final countSnap = await baseQuery.count().get();
    final reviewCount = countSnap.count ?? 0;
    if (reviewCount == 0) return (0, 0.0);

    // sum('rating')은 복합 인덱스 필요 → 최근 100개로 직접 계산
    final ratingSnap = await baseQuery.limit(100).get();
    final totalRating = ratingSnap.docs.fold<double>(
      0,
      (s, doc) => s + ((doc.data() as Map<String, dynamic>)['rating'] as num? ?? 0).toDouble(),
    );
    return (reviewCount, totalRating / ratingSnap.docs.length);
  }
}
