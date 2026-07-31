import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/ink_book_model.dart';
import '../models/ink_chart_model.dart';

class InkBookRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _books(String uid) =>
      _db.collection('users').doc(uid).collection('inkBooks');

  CollectionReference<Map<String, dynamic>> _chart(String uid, String bookId) =>
      _books(uid).doc(bookId).collection('inkChart');

  // ── inkBooks ────────────────────────────────────────────────────────
  Stream<List<InkBookModel>> watchBooks(String uid) {
    return _books(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => InkBookModel.fromMap(d.data(), d.id)).toList());
  }

  Future<String> createBook(String uid, String name, String coverColor) async {
    final id = const Uuid().v4();
    await _books(uid).doc(id).set(
      InkBookModel(
        id: id,
        name: name,
        coverColor: coverColor,
        createdAt: DateTime.now(),
        ownerUid: uid,
      ).toMap(),
    );
    return id;
  }

  Future<void> updateBook(String uid, String bookId, {required String name}) =>
      _books(uid).doc(bookId).update({'name': name});

  Future<void> updateBookVisibility(
    String uid,
    String bookId, {
    required String visibility, // 'public' | 'followers' | 'private'
    required String ownerNickname,
  }) =>
      _books(uid).doc(bookId).update({
        'visibility': visibility,
        'isPublic': visibility == 'public', // 구버전 쿼리 하위 호환
        'ownerUid': uid,
        'ownerNickname': ownerNickname,
      });

  /// 페이지 스타일/보기 방식 저장 — 다른 유저가 읽기 전용으로 볼 때도
  /// 소유자가 설정한 그대로 보이도록 book 문서에 함께 저장한다.
  Future<void> updateBookDisplaySettings(
    String uid,
    String bookId, {
    required String pageStyle, // 'lines' | 'grid' | 'plain'
    required String viewMode, // 'pageView' | 'scroll'
  }) =>
      _books(uid).doc(bookId).update({
        'pageStyle': pageStyle,
        'viewMode': viewMode,
      });

  /// 전체 공개 잉크북 목록 (공개 범위 = 'public')
  Future<List<InkBookModel>> getPublicBooks({int limit = 30}) async {
    final snap = await _db
        .collectionGroup('inkBooks')
        .where('isPublic', isEqualTo: true) // 구버전 데이터 포함
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => InkBookModel.fromMap(d.data(), d.id)).toList();
  }

  /// 특정 유저의 전체 공개 잉크북 (공개 범위 = 'public')
  ///
  /// uid를 이미 알고 있으므로 collectionGroup 대신 해당 유저의 서브컬렉션을 직접 조회한다
  /// (ownerUid가 비어있는 예전 문서도 걸리도록). 단, Firestore 보안 규칙이
  /// resource.data(visibility)를 검사하는 per-document 규칙이라 쿼리 자체에
  /// 그 필드를 where로 명시해야 한다 — where 없이 통째로 읽으면 결과셋에
  /// 규칙을 통과 못하는 문서(예: private)가 섞여 있을 수 있어 쿼리 전체가
  /// PERMISSION_DENIED로 거부된다. 클라이언트 필터링만으로는 안 됨.
  Future<List<InkBookModel>> getPublicBooksForUser(String uid) async {
    try {
      final snap = await _books(uid).where('visibility', isEqualTo: 'public').get();
      return snap.docs.map((d) => InkBookModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[InkBook] getPublicBooksForUser($uid) 실패: $e');
      rethrow;
    }
  }

  /// 특정 유저의 팔로워 공개 잉크북 (공개 범위 = 'followers')
  Future<List<InkBookModel>> getFollowersOnlyBooksForUser(String uid) async {
    try {
      final snap = await _books(uid).where('visibility', isEqualTo: 'followers').get();
      return snap.docs.map((d) => InkBookModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[InkBook] getFollowersOnlyBooksForUser($uid) 실패: $e');
      rethrow;
    }
  }

  Future<InkBookModel?> getBook(String uid, String bookId) async {
    final doc = await _books(uid).doc(bookId).get();
    if (!doc.exists) return null;
    return InkBookModel.fromMap(doc.data()!, doc.id);
  }

  /// Deletes the book document. Caller should delete subcollection entries + photos separately.
  Future<List<InkChartModel>> deleteBook(String uid, String bookId) async {
    // Fetch chart entries so caller can delete storage photos
    final snap = await _chart(uid, bookId).get();
    final entries = snap.docs.map((d) => InkChartModel.fromMap(d.data(), d.id)).toList();

    // Batch delete chart docs + book doc
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_books(uid).doc(bookId));
    await batch.commit();
    return entries;
  }

  // ── inkChart ─────────────────────────────────────────────────────────
  Stream<List<InkChartModel>> watchChart(String uid, String bookId) {
    return _chart(uid, bookId)
        .orderBy('order', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => InkChartModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addEntry(String uid, String bookId, InkChartModel entry) async {
    final snap = await _chart(uid, bookId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder =
        snap.docs.isEmpty ? 0 : ((snap.docs.first.data()['order'] as int? ?? 0) + 1);
    await _chart(uid, bookId).doc(entry.id).set({
      ...entry.toMap(),
      'order': nextOrder,
    });
  }

  Future<void> deleteEntry(String uid, String bookId, String chartId) =>
      _chart(uid, bookId).doc(chartId).delete();

  /// 잉크 스와치 내용 수정 — createdAt/order는 건드리지 않음
  Future<void> updateEntry(String uid, String bookId, InkChartModel entry) =>
      _chart(uid, bookId).doc(entry.id).update({
        'photoUrl': entry.photoUrl,
        'brand': entry.brand,
        'inkName': entry.inkName,
        'memo': entry.memo,
        'contentBlocks': entry.contentBlocks ?? FieldValue.delete(),
      });

  Future<void> reorderEntries(
      String uid, String bookId, List<InkChartModel> ordered) async {
    final batch = _db.batch();
    for (int i = 0; i < ordered.length; i++) {
      batch.update(_chart(uid, bookId).doc(ordered[i].id), {'order': i});
    }
    await batch.commit();
  }
}
