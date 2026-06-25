import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/wishlist_model.dart';

class WishlistRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _wishlist(String uid) =>
      _db.collection('users').doc(uid).collection('wishlist');

  Stream<List<WishlistItem>> watchWishlist(String uid) {
    return _wishlist(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => WishlistItem.fromMap(d.data(), d.id)).toList());
  }

  Future<bool> isWishlisted(String uid, String productId) async {
    final snap = await _wishlist(uid)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> add(String uid, WishlistItem item) async {
    final id = const Uuid().v4();
    await _wishlist(uid).doc(id).set(WishlistItem(
          id: id,
          type: item.type,
          productId: item.productId,
          productName: item.productName,
          brand: item.brand,
          hexColor: item.hexColor,
          createdAt: DateTime.now(),
        ).toMap());
  }

  Future<void> remove(String uid, String productId) async {
    final snap = await _wishlist(uid)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
