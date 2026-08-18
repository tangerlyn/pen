import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_system.dart';
import '../../core/utils/search_utils.dart';
import '../models/post_model.dart';
import '../models/reply_model.dart';

class PostRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<PostModel>> watchPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList());
  }

  Future<(List<PostModel>, DocumentSnapshot?)> fetchPosts({
    DocumentSnapshot? lastDoc,
    int limit = 20,
    String? category,
  }) async {
    if (category != null) {
      // Category filter: avoid composite index by skipping orderBy, sort client-side
      final snap = await _db
          .collection('posts')
          .where('category', isEqualTo: category)
          .limit(100)
          .get();
      final posts = snap.docs
          .map((d) => PostModel.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return (posts, null);
    }
    Query<Map<String, dynamic>> query = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    final snap = await query.get();
    final posts = snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList();
    final nextDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (posts, nextDoc);
  }

  Stream<List<PostModel>> watchUserPosts(String uid) {
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList());
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data()!, doc.id);
  }

  Stream<PostModel?> watchPost(String postId) {
    return _db.collection('posts').doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PostModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    await _db.collection(AppConstants.reportsCol).add({
      'targetType': 'post',
      'targetId': postId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    if (title.isNotEmpty || body.isNotEmpty) {
      data['searchIndex'] = SearchUtils.buildIndex(title, body);
    }
    await _db.collection('posts').doc(postId).update(data);
  }

  Future<String> createPost({
    required String authorId,
    required String authorNickname,
    required int authorLevel,
    required String title,
    required String body,
    List<String> imageUrls = const [],
    String? category,
    List<Map<String, dynamic>>? contentBlocks,
  }) async {
    final data = PostModel(
      id: '',
      authorId: authorId,
      authorNickname: authorNickname,
      authorLevel: authorLevel,
      title: title,
      body: body,
      imageUrls: imageUrls,
      contentBlocks: contentBlocks,
      category: category,
      createdAt: DateTime.now(),
    ).toMap();
    data['searchIndex'] = SearchUtils.buildIndex(title, body);
    final ref = await _db.collection('posts').add(data);
    return ref.id;
  }

  Stream<List<PostCommentModel>> watchComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => PostCommentModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorNickname,
    required int authorLevel,
    required String body,
  }) async {
    final batch = _db.batch();
    final commentRef = _db.collection('posts').doc(postId).collection('comments').doc();
    batch.set(commentRef, PostCommentModel(
      id: '',
      postId: postId,
      authorId: authorId,
      authorNickname: authorNickname,
      authorLevel: authorLevel,
      body: body,
      createdAt: DateTime.now(),
    ).toMap());
    batch.update(_db.collection('posts').doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final commentRef = _db.collection('posts').doc(postId).collection('comments').doc(commentId);
    final postRef = _db.collection('posts').doc(postId);

    final repliesSnap = await commentRef.collection('replies').limit(1).get();
    final batch = _db.batch();
    if (repliesSnap.docs.isEmpty) {
      batch.delete(commentRef);
    } else {
      batch.update(commentRef, {'isDeleted': true, 'body': FieldValue.delete()});
    }
    batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> updateComment(String postId, String commentId, String body) async {
    await _db.collection('posts').doc(postId).collection('comments').doc(commentId)
        .update({'body': body, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<List<ReplyModel>> watchReplies(String postId, String commentId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => ReplyModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addReply({
    required String postId,
    required String commentId,
    required ReplyModel reply,
  }) async {
    final replyRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc();
    final batch = _db.batch();
    batch.set(replyRef, reply.toMap());
    batch.update(_db.collection('posts').doc(postId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    final replyRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);
    final batch = _db.batch();
    batch.delete(replyRef);
    batch.update(_db.collection('posts').doc(postId), {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> updateReply(
      String postId, String commentId, String replyId, String body) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .update({'body': body, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<List<PostModel>> watchLikedPosts(String uid) {
    return _db
        .collectionGroup('likes')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) async {
          final futures = snap.docs
              .where((doc) => doc.reference.parent.parent?.parent.id == 'posts')
              .map((doc) async {
            final postRef = doc.reference.parent.parent!;
            final postDoc = await postRef.get();
            if (!postDoc.exists) return null;
            return PostModel.fromMap(
                postDoc.data() as Map<String, dynamic>, postDoc.id);
          });
          return (await Future.wait(futures)).whereType<PostModel>().toList();
        });
  }

  Future<List<PostModel>> getLikedPosts(String uid) async {
    final querySnapshot = await _db
        .collectionGroup('likes')
        .where('uid', isEqualTo: uid)
        .get();

    final futures = querySnapshot.docs
        .where((doc) => doc.reference.parent.parent?.parent.id == 'posts')
        .map((doc) async {
      final postRef = doc.reference.parent.parent!;
      final postDoc = await postRef.get();
      if (!postDoc.exists) return null;
      return PostModel.fromMap(postDoc.data() as Map<String, dynamic>, postDoc.id);
    });

    return (await Future.wait(futures)).whereType<PostModel>().toList();
  }

  Stream<bool> watchLikeStatus(String postId, String uid) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // 배치(batch)는 "현재 상태를 읽고 반대로 뒤집는" 방식이라 바깥의 withRetry가
  // 재시도할 때마다 매번 다시 뒤집혀서 좋아요 수가 드리프트하는 문제가 있었다
  // (review_repository.dart와 달리 목표 상태를 안 받고 매번 현재 상태의 반대로
  // 커밋해버림). 트랜잭션 + 명시적 목표 상태(isLiked)로 바꿔서, 같은 목표로
  // 여러 번 재시도해도 안전하게 수렴하도록 review_repository.dart와 동일한
  // 패턴으로 맞춘다.
  Future<void> toggleLike(
    String postId,
    String uid,
    String authorId,
    bool isLiked,
  ) async {
    final likeRef = _db.collection('posts').doc(postId).collection('likes').doc(uid);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception('Post not found');

      final likeDoc = await transaction.get(likeRef);
      final data = postDoc.data() as Map<String, dynamic>?;
      final currentLikeCount = data?['likeCount'] as num? ?? 0;

      if (isLiked) {
        if (!likeDoc.exists) {
          transaction.set(likeRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'likeCount': currentLikeCount + 1});
          // 작성자에게 좋아요 EXP 지급
          transaction.update(
            _db.collection('users').doc(authorId),
            {'exp': FieldValue.increment(LevelSystem.expLike)},
          );
        }
      } else {
        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {'likeCount': currentLikeCount > 0 ? currentLikeCount - 1 : 0});
        }
      }
    });
  }
}
