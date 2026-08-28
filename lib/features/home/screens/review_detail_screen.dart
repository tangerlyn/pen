import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
// import 'package:share_plus/share_plus.dart' show Share; // 외부 공유 버튼 주석 처리로 미사용
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_utils.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../core/utils/post_date_format.dart';
import '../../../shared/widgets/image_viewer_screen.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../providers/review_detail_provider.dart';
import '../../archive/providers/archive_detail_provider.dart';
// import '../../../shared/widgets/common/star_rating.dart'; // 별점 시스템 비활성화
import '../../../shared/widgets/review/comment_tile.dart';
import '../../review/screens/review_write_screen.dart';
import '../providers/feed_provider.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/content_moderation.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/level_badge.dart';
import '../../../shared/widgets/linkified_text.dart';
import '../../../shared/controllers/comment_composer_controller.dart';
part '../widgets/review_detail_content.dart';
part '../widgets/review_comment_widgets.dart';

final _reviewAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
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
  final _composer = CommentComposerController();
  bool _hasActiveEdit = false;

  @override
  void dispose() {
    _pageController.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String nickname) {
    setState(() => _composer.startReply(commentId, nickname));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composer.focusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() => _composer.clearReply(clearText: true));
  }

  Future<void> _submitInput() async {
    final text = _composer.trimmedText;
    if (text.isEmpty) return;

    try {
      if (_composer.isReplying) {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;
        await withRetry(
          () => ref
              .read(reviewRepoProvider)
              .addReply(
                widget.reviewId,
                _composer.replyTargetCommentId!,
                ReplyModel(
                  id: '',
                  authorId: user.uid,
                  authorNickname: user.nickname,
                  authorLevel: user.level,
                  body: text,
                  createdAt: DateTime.now(),
                ),
              ),
        );
        ref
            .read(reviewDetailProvider(widget.reviewId).notifier)
            .updateCommentCount(1);
        setState(_composer.clearReply);
      } else {
        await ref
            .read(reviewDetailProvider(widget.reviewId).notifier)
            .addComment(text);
      }
      _composer.textController.clear();
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
        loading: () =>
            const SingleChildScrollView(child: ReviewDetailSkeleton()),
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
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinkifiedText(
                text,
                style: const TextStyle(fontSize: 15, height: 1.75),
              ),
            ),
          );
        }
      } else if (block['type'] == 'image') {
        final url = block['url'] as String? ?? '';
        if (url.isNotEmpty) {
          final imgIndex = allImageUrls.indexOf(url);
          widgets.add(
            Padding(
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
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildLegacyImages(
    BuildContext context,
    List<String> imageUrls,
  ) {
    return imageUrls
        .asMap()
        .entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrls: imageUrls,
                    initialIndex: e.key,
                  ),
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
          ),
        )
        .toList();
  }

  Widget _buildContent(
    BuildContext context,
    ReviewModel review,
    String? currentUid,
  ) {
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
                //         '$title\n$body\n\n펜귄 - 만년필 잉크 커뮤니티',
                //         sharePositionOrigin:
                //             box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                //       );
                //     },
                //   ),
                // ),
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
                // ── LAYOUT A: 블로그 형식 (커뮤니티 상세와 동일한 배치: 제목 → 작성자/날짜) ──
                // 제목
                if (review.title.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                // 작성자 + 날짜
                SliverToBoxAdapter(
                  child: _ProfileRow(review: review, currentUid: currentUid),
                ),
                // 장비 카드
                SliverToBoxAdapter(child: _GearCard(review: review)),
                // 별점 시스템 비활성화 — 재활성화 시 주석 해제
                // SliverToBoxAdapter(
                //   child: Padding(
                //     padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                //     child: StarRatingDisplay(rating: review.rating),
                //   ),
                // ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                // 블로그 본문 (contentBlocks 또는 기존 body+imageUrls 폴백)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (review.contentBlocks != null &&
                            review.contentBlocks!.isNotEmpty)
                          ..._buildReviewContentBlocks(
                            context,
                            review.contentBlocks!,
                            review.imageUrls,
                          )
                        else ...[
                          if (review.imageUrls.isNotEmpty)
                            ..._buildLegacyImages(context, review.imageUrls),
                          if (review.body.isNotEmpty) ...[
                            LinkifiedText(
                              review.body,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.75,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
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
                            .read(
                              reviewDetailProvider(widget.reviewId).notifier,
                            )
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
                  reviewAuthorId: review.authorId,
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
              controller: _composer.textController,
              focusNode: _composer.focusNode,
              replyTargetNickname: _composer.replyTargetNickname,
              onCancelReply: _cancelReply,
              onSubmit: _submitInput,
            ),
          ),
      ],
    );
  }

  void _showMoreOptions(
    BuildContext context,
    ReviewModel review,
    bool isOwner,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  '삭제',
                  style: TextStyle(color: AppColors.error),
                ),
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
                  final authorAsync = ref.read(
                    _reviewAuthorProvider(review.authorId),
                  );
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
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.error,
                ),
                title: const Text(
                  '신고하기',
                  style: TextStyle(color: AppColors.error),
                ),
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
              await ref
                  .read(reviewRepoProvider)
                  .deleteReview(review.id, review);
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
