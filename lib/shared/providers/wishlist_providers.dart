import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/wishlist_model.dart';
import '../../data/repositories/wishlist_repository.dart';
import 'providers.dart';

final wishlistRepoProvider = Provider<WishlistRepository>((ref) => WishlistRepository());

final wishlistProvider = StreamProvider.family<List<WishlistItem>, String>((ref, uid) {
  return ref.watch(wishlistRepoProvider).watchWishlist(uid);
});

final wishlistStatusProvider = FutureProvider.family<bool, String>((ref, productId) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  return ref.read(wishlistRepoProvider).isWishlisted(uid, productId);
});

// 위시리스트 액션 (추가/제거 토글)
final wishlistActionsProvider = Provider<_WishlistActions>((ref) => _WishlistActions(ref));

class _WishlistActions {
  const _WishlistActions(this._ref);
  final Ref _ref;

  Future<void> toggle({
    required String type,
    required String productId,
    required String productName,
    required String brand,
    String hexColor = '',
  }) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final repo = _ref.read(wishlistRepoProvider);
    final isAdded = await repo.isWishlisted(uid, productId);
    if (isAdded) {
      await repo.remove(uid, productId);
    } else {
      await repo.add(
        uid,
        WishlistItem(
          id: '',
          type: type,
          productId: productId,
          productName: productName,
          brand: brand,
          hexColor: hexColor,
          createdAt: DateTime.now(),
        ),
      );
    }
    _ref.invalidate(wishlistStatusProvider(productId));
    _ref.invalidate(wishlistProvider(uid));
  }
}
