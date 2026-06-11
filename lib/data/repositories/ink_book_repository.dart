import 'package:cloud_firestore/cloud_firestore.dart';
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
      InkBookModel(id: id, name: name, coverColor: coverColor, createdAt: DateTime.now())
          .toMap(),
    );
    return id;
  }

  Future<void> updateBook(String uid, String bookId, {required String name}) =>
      _books(uid).doc(bookId).update({'name': name});

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

  Future<void> reorderEntries(
      String uid, String bookId, List<InkChartModel> ordered) async {
    final batch = _db.batch();
    for (int i = 0; i < ordered.length; i++) {
      batch.update(_chart(uid, bookId).doc(ordered[i].id), {'order': i});
    }
    await batch.commit();
  }
}
