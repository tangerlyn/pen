import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
// import 'package:share_plus/share_plus.dart' show Share; // 외부 공유 버튼 주석 처리로 미사용
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_utils.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../shared/widgets/image_viewer_screen.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../providers/review_detail_provider.dart';
import '../../archive/providers/archive_detail_provider.dart';
import '../../../shared/widgets/common/star_rating.dart';
import '../../../shared/widgets/review/comment_tile.dart';
import '../../review/screens/review_write_screen.dart';
import '../providers/feed_provider.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/content_moderation.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/level_badge.dart';

final _reviewAuthorProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class ReviewDetailScreen extends ConsumerStatefulWidget {
  const ReviewDetailScreen({super.key, required this.reviewId});
  final String reviewId;

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  final _pageController = PageController();
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _expanded = false;
  bool _hasActiveEdit = false;
  String? _replyTargetCommentId;
  String? _replyTargetNickname;

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String nickname) {
    setState(() {
      _replyTargetCommentId = commentId;
      _replyTargetNickname = nickname;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commentFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyTargetCommentId = null;
      _replyTargetNickname = null;
    });
    _commentController.clear();
  }

  Future<void> _submitInput() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      if (_replyTargetCommentId != null) {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;
        await withRetry(() => ref.read(reviewRepoProvider).addReply(
              widget.reviewId,
              _replyTargetCommentId!,
              ReplyModel(
                id: '',
                authorId: user.uid,
                authorNickname: user.nickname,
                authorLevel: user.level,
                body: text,
                createdAt: DateTime.now(),
              ),
            ));
        ref.read(reviewDetailProvider(widget.reviewId).notifier).updateCommentCount(1);
        setState(() {
          _replyTargetCommentId = null;
          _replyTargetNickname = null;
        });
      } else {
        await ref
            .read(reviewDetailProvider(widget.reviewId).notifier)
            .addComment(text);
      }
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인터넷 연결을 확인해주세요'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewDetailProvider(widget.reviewId));
    final currentUid = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: state.when(
        loading: () => const SingleChildScrollView(child: DetailSkeleton()),
        error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
        data: (review) => review == null
            ? const Center(child: Text('삭제된 리뷰입니다.'))
            : _buildContent(context, review, currentUid),
      ),
    );
  }

  List<Widget> _buildReviewContentBlocks(
    BuildContext context,
    List<Map<String, dynamic>> blocks,
    List<String> allImageUrls,
  ) {
    final widgets = <Widget>[];
    for (final block in blocks) {
      if (block['type'] == 'text') {
        final text = block['content'] as String? ?? '';
        if (text.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(text, style: const TextStyle(fontSize: 15, height: 1.75)),
          ));
        }
      } else if (block['type'] == 'image') {
        final url = block['url'] as String? ?? '';
        if (url.isNotEmpty) {
          final imgIndex = allImageUrls.indexOf(url);
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrls: allImageUrls.isNotEmpty ? allImageUrls : [url],
                    initialIndex: imgIndex >= 0 ? imgIndex : 0,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ));
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildLegacyImages(BuildContext context, List<String> imageUrls) {
    return imageUrls.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(imageUrls: imageUrls, initialIndex: e.key),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: e.value,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    )).toList();
  }

  Widget _buildContent(BuildContext context, ReviewModel review, String? currentUid) {
    final isOwner = review.authorId == currentUid;

    return Column(
      children: [
        // ── AppBar ──────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Container(
            height: 52,
            color: AppColors.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                // 외부 공유 버튼 — 당장 불필요해 보여 주석 처리 (재활성화 시 복구)
                // Builder(
                //   builder: (btnContext) => IconButton(
                //     icon: const Icon(Icons.share_outlined),
                //     onPressed: () {
                //       final title = review.title.isNotEmpty ? review.title : '리뷰';
                //       final body = review.body.isNotEmpty
                //           ? review.body.substring(0, review.body.length.clamp(0, 80))
                //           : '';
                //       final box = btnContext.findRenderObject() as RenderBox?;
                //       Share.share(
                //         '$title\n$body\n\n문어다방 - 만년필 잉크 커뮤니티',
                //         sharePositionOrigin:
                //             box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                //       );
                //     },
                //   ),
                // ),
                if (currentUid != null)
                  IconButton(
                    icon: Icon(
                      review.isScrapped ? Icons.bookmark : Icons.bookmark_border,
                      color: review.isScrapped ? AppColors.primary : null,
                    ),
                    onPressed: () async {
                      final willScrap = !review.isScrapped;
                      try {
                        await ref
                            .read(reviewDetailProvider(widget.reviewId).notifier)
                            .toggleScrap();
                        if (willScrap && context.mounted) {
                          showScrapToast(context);
                        }
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('인터넷 연결을 확인해주세요'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showMoreOptions(context, review, isOwner),
                ),
              ],
            ),
          ),
        ),
        // ── 본문 ─────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: CustomScrollView(
            slivers: [
              // ── LAYOUT A: 블로그 형식 ─────────────────────
              // 프로필
              SliverToBoxAdapter(
                child: _ProfileRow(review: review, currentUid: currentUid),
              ),
              // 제목
              if (review.title.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      review.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              // 장비 카드
              SliverToBoxAdapter(child: _GearCard(review: review)),
              // 별점
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: StarRatingDisplay(rating: review.rating),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // 블로그 본문 (contentBlocks 또는 기존 body+imageUrls 폴백)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.contentBlocks != null && review.contentBlocks!.isNotEmpty)
                        ..._buildReviewContentBlocks(context, review.contentBlocks!, review.imageUrls)
                      else ...[
                        if (review.imageUrls.isNotEmpty)
                          ..._buildLegacyImages(context, review.imageUrls),
                        if (review.body.isNotEmpty) ...[
                          Text(
                            review.body,
                            style: const TextStyle(fontSize: 15, height: 1.75),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            timeago.format(review.createdAt, locale: 'ko'),
                            style: const TextStyle(
                                color: AppColors.textTertiary, fontSize: 12),
                          ),
                          if (review.updatedAt != null) ...[
                            const SizedBox(width: 6),
                            const Text('· 수정됨',
                                style: TextStyle(
                                    color: AppColors.textTertiary, fontSize: 12)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // ── LAYOUT B: 기존 형식 (사진 슬라이더 상단) ─────
              // SliverToBoxAdapter(
              //   child: _PhotoSlider(review: review, controller: _pageController),
              // ),
              // SliverToBoxAdapter(
              //   child: _ProfileRow(review: review, currentUid: currentUid),
              // ),
              // if (review.title.isNotEmpty)
              //   SliverToBoxAdapter(
              //     child: Padding(
              //       padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              //       child: Text(review.title,
              //           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
              //     ),
              //   ),
              // SliverToBoxAdapter(child: _GearCard(review: review)),
              // SliverToBoxAdapter(
              //   child: Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16),
              //     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              //       StarRatingDisplay(rating: review.rating),
              //       const SizedBox(height: 12),
              //       if (review.body.isNotEmpty) ...[
              //         Text(review.body, style: const TextStyle(fontSize: 15, height: 1.6)),
              //         const SizedBox(height: 12),
              //       ],
              //       Row(children: [
              //         Text(timeago.format(review.createdAt, locale: 'ko'),
              //             style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              //         if (review.updatedAt != null) ...[
              //           const SizedBox(width: 6),
              //           const Text('· 수정됨', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              //         ],
              //       ]),
              //       const SizedBox(height: 8),
              //     ]),
              //   ),
              // ),
              // 액션 바
              SliverToBoxAdapter(
                child: _ActionBar(
                  review: review,
                  currentUid: currentUid,
                  onLike: () async {
                    try {
                      await ref
                          .read(reviewDetailProvider(widget.reviewId).notifier)
                          .toggleLike();
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('인터넷 연결을 확인해주세요'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ),

              const SliverToBoxAdapter(child: Divider()),
              // 댓글
              _CommentList(
                reviewId: widget.reviewId,
                currentUid: currentUid,
                onReplyTap: _startReply,
                onCommentDeleted: () =>
                    ref.invalidate(reviewDetailProvider(widget.reviewId)),
                onReplyDeleted: () => ref
                    .read(reviewDetailProvider(widget.reviewId).notifier)
                    .updateCommentCount(-1),
                onEditStart: () => setState(() => _hasActiveEdit = true),
                onEditEnd: () => setState(() => _hasActiveEdit = false),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          ),
        ),
        // ── 댓글 입력창 ───────────────────────────────────
        if (!_hasActiveEdit)
          SafeArea(
            top: false,
            child: _CommentInput(
              controller: _commentController,
              focusNode: _commentFocusNode,
              replyTargetNickname: _replyTargetNickname,
              onCancelReply: _cancelReply,
              onSubmit: _submitInput,
            ),
          ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, ReviewModel review, bool isOwner) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewWriteScreen(reviewToEdit: review),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('삭제', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, review);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('사용자 차단하기'),
                onTap: () async {
                  Navigator.pop(context);
                  final authorAsync =
                      ref.read(_reviewAuthorProvider(review.authorId));
                  final nickname =
                      authorAsync.value?.nickname ?? review.authorId;
                  await showBlockDialog(
                    context,
                    ref,
                    targetUid: review.authorId,
                    targetNickname: nickname,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                title: const Text('신고하기',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  showReportSheet(
                    context,
                    ref,
                    targetType: 'review',
                    targetId: review.id,
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReviewModel review) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Storage 이미지 삭제
              final storage = ref.read(storageServiceProvider);
              for (final url in review.imageUrls) {
                await storage.deleteByUrl(url);
              }
              await ref.read(reviewRepoProvider).deleteReview(review.id, review);
              ref.invalidate(feedProvider);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── 사진 슬라이더 ─────────────────────────────────────────────
class _PhotoSlider extends StatefulWidget {
  const _PhotoSlider({required this.review, required this.controller});
  final ReviewModel review;
  final PageController controller;

  @override
  State<_PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<_PhotoSlider> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        SizedBox(
          height: size.width,
          child: PageView.builder(
            controller: widget.controller,
            itemCount: widget.review.imageUrls.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrls: widget.review.imageUrls,
                    initialIndex: i,
                  ),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: widget.review.imageUrls[i],
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // 페이지 인디케이터
        if (widget.review.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: widget.controller,
                count: widget.review.imageUrls.length,
                effect: const WormEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white54,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 프로필 ────────────────────────────────────────────────────
class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.review, required this.currentUid});
  final ReviewModel review;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(_reviewAuthorProvider(review.authorId));
    final isOwnPost = review.authorId == currentUid;
    final isDeletedUser = authorAsync.valueOrNull == null;
    final isFollowing = (!isOwnPost && currentUid != null && !isDeletedUser)
        ? ref
                .watch(followStatusProvider((currentUid!, review.authorId)))
                .valueOrNull ??
            false
        : false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => navigateToProfile(context, ref, review.authorId),
            child: authorAsync.when(
              data: (user) => CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(user!.profileImageUrl!)
                    : null,
                child: user?.profileImageUrl == null
                    ? const Icon(Icons.person, size: 20, color: AppColors.textTertiary)
                    : null,
              ),
              loading: () => const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.chipBackground,
              ),
              error: (_, __) => const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.chipBackground,
                child: Icon(Icons.person, size: 20, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => navigateToProfile(context, ref, review.authorId),
              child: authorAsync.when(
                data: (user) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user == null ? '(알 수 없음) (탈퇴)' : user.nickname,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (user != null) ...[
                      const SizedBox(width: 6),
                      LevelBadge(user.level),
                    ],
                  ],
                ),
                loading: () => Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                error: (_, __) => Text(
                  review.authorId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          if (!isOwnPost && currentUid != null && !isDeletedUser)
            isFollowing
                ? ElevatedButton(
                    onPressed: () =>
                        ref.read(userRepoProvider).unfollow(currentUid!, review.authorId),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(72, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                      backgroundColor: AppColors.chipBackground,
                      foregroundColor: AppColors.textSecondary,
                      elevation: 0,
                    ),
                    child: const Text('팔로잉'),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        ref.read(userRepoProvider).follow(currentUid!, review.authorId),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text('팔로우'),
                  ),
        ],
      ),
    );
  }
}

// ── 장비 카드 ────────────────────────────────────────────────
class _GearCard extends StatelessWidget {
  const _GearCard({required this.review});
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    if (review.inkIds.isEmpty && review.penIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...review.inkIds.map((id) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _GearChip(
                    type: 'ink',
                    id: id,
                    onTap: () => context.push('/archive/ink/$id'),
                  ),
                )),
            ...review.penIds.map((id) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _GearChip(
                    type: 'pen',
                    id: id,
                    onTap: () => context.push('/archive/pen/$id'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _GearChip extends ConsumerWidget {
  const _GearChip({required this.type, required this.id, required this.onTap});
  final String type;
  final String id;
  final VoidCallback onTap;

  static const _inkBg     = Color(0xFFE3F2FD);
  static const _inkBorder = Color(0xFF90CAF9);
  static const _inkFg     = Color(0xFF1565C0);
  static const _penBg     = Color(0xFFF3E5F5);
  static const _penBorder = Color(0xFFCE93D8);
  static const _penFg     = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInk = type == 'ink';
    final dataState = ref.watch(archiveDetailProvider((type: type, productId: id)));

    final label = dataState.when(
      data: (data) {
        if (data == null) return isInk ? '잉크' : '만년필';
        return isInk ? '${data.brand} ${data.name}' : '${data.brand} ${data.modelName}';
      },
      loading: () => '로딩중...',
      error: (_, __) => isInk ? '잉크' : '만년필',
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isInk ? _inkBg : _penBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isInk ? _inkBorder : _penBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInk ? Icons.water_drop_outlined : Icons.edit_outlined,
              size: 12,
              color: isInk ? _inkFg : _penFg,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isInk ? _inkFg : _penFg),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 액션 바 ──────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.review,
    required this.currentUid,
    required this.onLike,
  });
  final ReviewModel review;
  final String? currentUid;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            icon: review.isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${review.likeCount}',
            color: review.isLiked ? AppColors.error : null,
            onTap: onLike,
          ),
          const SizedBox(width: 16),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: '${review.commentCount}',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── 댓글 목록 ────────────────────────────────────────────────
class _CommentList extends ConsumerWidget {
  const _CommentList({
    required this.reviewId,
    required this.currentUid,
    required this.onReplyTap,
    required this.onCommentDeleted,
    this.onReplyDeleted,
    this.onEditStart,
    this.onEditEnd,
  });
  final String reviewId;
  final String? currentUid;
  final void Function(String commentId, String nickname) onReplyTap;
  final VoidCallback onCommentDeleted;
  final VoidCallback? onReplyDeleted;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsProvider(reviewId));
    return comments.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (list) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => CommentTile(
            comment: list[i],
            reviewId: reviewId,
            currentUid: currentUid,
            onReplyTap: onReplyTap,
            onDeleted: onCommentDeleted,
            onReplyDeleted: onReplyDeleted,
            onEditStart: onEditStart,
            onEditEnd: onEditEnd,
          ),
          childCount: list.length,
        ),
      ),
    );
  }
}

// ── 댓글 입력창 ──────────────────────────────────────────────
class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.replyTargetNickname,
    this.onCancelReply,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final String? replyTargetNickname;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTargetNickname != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.chipBackground,
            child: Row(
              children: [
                Text('@$replyTargetNickname 에게 답글',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: onCancelReply,
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: replyTargetNickname != null
                        ? '답글을 입력하세요...'
                        : '댓글을 입력하세요...',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    counterText: '',
                  ),
                  maxLines: null,
                  maxLength: replyTargetNickname != null
                      ? AppConstants.maxReply
                      : AppConstants.maxComment,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onSubmit,
                icon: const Icon(Icons.send, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
