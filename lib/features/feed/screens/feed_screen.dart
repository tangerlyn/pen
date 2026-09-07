import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/post_model.dart';
import '../../../features/review/screens/review_feed_screen.dart';
import '../../../features/community/screens/community_screen.dart';
import '../../../features/home/providers/home_discovery_provider.dart';
import '../../../features/community/providers/community_provider.dart';
import '../../../shared/widgets/tap_scale.dart';

// ── 피드 아이템 sealed type ────────────────────────────────────────────────
sealed class _FeedEntry {
  DateTime get createdAt;
}

final class _ReviewEntry extends _FeedEntry {
  _ReviewEntry(this.review);
  final ReviewModel review;
  @override
  DateTime get createdAt => review.createdAt;
}

final class _PostEntry extends _FeedEntry {
  _PostEntry(this.post);
  final PostModel post;
  @override
  DateTime get createdAt => post.createdAt;
}

// ── FeedScreen ────────────────────────────────────────────────────────────
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('피드', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search?type=all'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          dividerColor: AppColors.divider,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '리뷰'),
            Tab(text: '커뮤니티'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AllFeedTab(),
          ReviewFeedScreen(showAppBar: false),
          CommunityScreen(showAppBar: false),
        ],
      ),
    );
  }
}

// ── 전체 탭: 리뷰 + 커뮤니티 최신순 혼합 목록 ─────────────────────────────
class _AllFeedTab extends ConsumerWidget {
  const _AllFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(homeLatestReviewsProvider);
    final postsAsync = ref.watch(filteredPostsProvider);

    final isLoading = reviewsAsync.isLoading && postsAsync.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final reviews = reviewsAsync.valueOrNull ?? [];
    final posts = postsAsync.valueOrNull ?? [];

    final entries = <_FeedEntry>[
      ...reviews.map(_ReviewEntry.new),
      ...posts.map(_PostEntry.new),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          '아직 게시물이 없어요.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final entry = entries[i];
        return switch (entry) {
          _ReviewEntry(:final review) => _ReviewListItem(review: review),
          _PostEntry(:final post) => _PostListItem(post: post),
        };
      },
    );
  }
}

// ── 리뷰 목록 아이템 ───────────────────────────────────────────────────────
class _ReviewListItem extends StatelessWidget {
  const _ReviewListItem({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = review.thumbnailUrl.isNotEmpty;

    return TapScale(
      onTap: () => context.push('/review/${review.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타입 배지 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TypeBadge.review,
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          review.title.isNotEmpty ? review.title : '(제목 없음)',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 별점 시스템 비활성화 — 재활성화 시 주석 해제
                  // Row(
                  //   children: [
                  //     const Icon(Icons.star,
                  //         size: 13, color: Colors.amber),
                  //     const SizedBox(width: 2),
                  //     Text(
                  //       review.rating.toStringAsFixed(1),
                  //       style: AppTextStyles.labelMedium.copyWith(
                  //           fontWeight: FontWeight.w600),
                  //     ),
                  //     if (review.body.isNotEmpty) ...[
                  //       const SizedBox(width: 8),
                  //       Expanded(
                  //         child: Text(
                  //           review.body,
                  //           style: AppTextStyles.labelMedium,
                  //           maxLines: 1,
                  //           overflow: TextOverflow.ellipsis,
                  //         ),
                  //       ),
                  //     ],
                  //   ],
                  // ),
                  if (review.body.isNotEmpty)
                    Text(
                      review.body,
                      style: AppTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // 하단 메타
                  Row(
                    children: [
                      Text(
                        timeago.format(review.createdAt, locale: 'ko'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${review.likeCount}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${review.commentCount}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasThumbnail) ...[
              const SizedBox(width: AppSpacing.md),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: CachedNetworkImage(
                    imageUrl: review.thumbnailUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 커뮤니티 목록 아이템 ───────────────────────────────────────────────────
class _PostListItem extends StatelessWidget {
  const _PostListItem({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrls.isNotEmpty;

    return TapScale(
      onTap: () => context.push('/community/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타입 배지 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TypeBadge.community,
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.title,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.body,
                    style: AppTextStyles.labelMedium,
                    maxLines: hasImage ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorNickname,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        timeago.format(post.createdAt, locale: 'ko'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentCount}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.likeCount}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AppSpacing.md),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrls.first,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 타입 배지 ─────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge._({
    required this.label,
    required this.color,
    required this.bg,
  });
  final String label;
  final Color color;
  final Color bg;

  static const review = _TypeBadge._(
    label: '리뷰',
    color: Color(0xFF6A3DE8),
    bg: Color(0xFFF0EAFF),
  );
  static const community = _TypeBadge._(
    label: '커뮤니티',
    color: AppColors.success,
    bg: AppColors.successBg,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
