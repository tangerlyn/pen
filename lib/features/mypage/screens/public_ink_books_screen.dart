import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/tap_scale.dart';

class PublicInkBooksScreen extends ConsumerWidget {
  const PublicInkBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(publicInkBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공개 잉크 차트'),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(publicInkBooksProvider),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyStateWidget(
          icon: Icons.cloud_off_outlined,
          message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
        ),
        data: (books) {
          if (books.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.photo_album_outlined,
              message: '아직 공개된 잉크 차트가 없습니다.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: books.length,
            itemBuilder: (_, i) {
              final book = books[i];
              return TapScale(
                onTap: () => context.push(
                  '/public-ink-books/${book.ownerUid}/${book.id}',
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: book.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: book.color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: book.color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: book.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        book.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.ownerNickname.isNotEmpty ? book.ownerNickname : '익명',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
