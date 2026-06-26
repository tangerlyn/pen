import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wishlist_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/wishlist_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/ink_drop_circle.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final wishlistAsync = ref.watch(wishlistProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('위시리스트'),
        scrolledUnderElevation: 0,
      ),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyStateWidget(
          icon: Icons.cloud_off_outlined,
          message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.favorite_border,
              message: '위시리스트가 비어있습니다.\n마음에 드는 잉크나 만년필을\n추가해보세요!',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _WishlistTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  const _WishlistTile({required this.item});
  final WishlistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    Color inkColor = const Color(0xFFCCCCCC);
    if (item.hexColor.isNotEmpty) {
      try {
        inkColor = Color(int.parse('FF${item.hexColor.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: item.type == 'ink'
          ? InkDropCircle(color: inkColor, size: 40)
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
            ),
      title: Text(item.productName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(item.brand,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
        onPressed: () async {
          if (uid == null) return;
          await ref.read(wishlistRepoProvider).remove(uid, item.productId);
          if (!context.mounted) return;
          ref.invalidate(wishlistProvider(uid));
          ref.invalidate(wishlistStatusProvider(item.productId));
        },
      ),
      onTap: () => context.push('/archive/${item.type}/${item.productId}'),
    );
  }
}
