import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/owned_ink_model.dart';

class OwnedInkRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _owned(String uid) =>
      _db.collection('users').doc(uid).collection('ownedInks');

  Stream<List<OwnedInk>> watchOwnedInks(String uid) {
    return _owned(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OwnedInk.fromMap(d.data(), d.id)).toList());
  }

  Stream<bool> watchIsOwned(String uid, String inkId) =>
      _owned(uid).doc(inkId).snapshots().map((d) => d.exists);

  Future<void> add(String uid, OwnedInk ink) =>
      _owned(uid).doc(ink.inkId).set(ink.toMap());

  Future<void> remove(String uid, String inkId) => _owned(uid).doc(inkId).delete();
}
