import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:share_plus/share_plus.dart' show Share; // 외부 공유 버튼 주석 처리로 미사용
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/level_system.dart';
import '../../../core/utils/network_utils.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../core/utils/post_date_format.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../providers/community_provider.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../shared/widgets/level_badge.dart';
import '../../../shared/widgets/author_badge.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/content_moderation.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/image_viewer_screen.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/linkified_text.dart';
import '../../../shared/controllers/comment_composer_controller.dart';
import 'post_write_screen.dart';
part '../widgets/post_detail_content.dart';
part '../widgets/post_comment_widgets.dart';

final _postAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _composer = CommentComposerController();
  bool _hasActiveEdit = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String nickname) {
    setState(() => _composer.startReply(commentId, nickname));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composer.focusNode.requestFocus();
    });
  }

  Future<void> _submitComment() async {
    final text = _composer.trimmedText;
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(_composer.beginSubmit);
    try {
      if (_composer.isReplying) {
        await withRetry(
          () => ref
              .read(postRepositoryProvider)
              .addReply(
                postId: widget.postId,
                commentId: _composer.replyTargetCommentId!,
                reply: ReplyModel(
                  id: '',
                  authorId: user.uid,
                  authorNickname: user.nickname,
                  authorLevel: user.level,
                  body: text,
                  createdAt: DateTime.now(),
                ),
              ),
        );
        setState(_composer.clearReply);
      } else {
        await withRetry(
          () => ref
              .read(postRepositoryProvider)
              .addComment(
                postId: widget.postId,
                authorId: user.uid,
                authorNickname: user.nickname,
                authorLevel: user.level,
                body: text,
              ),
        );
        final levelUp = await ref
            .read(userRepoProvider)
            .addExpAndCheck(user.uid, LevelSystem.expComment);
        if (levelUp != null && mounted) {
          ref.read(levelUpProvider.notifier).state = levelUp;
        }
      }
      _composer.textController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인터넷 연결을 확인해주세요'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(_composer.finishSubmit);
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _showMoreOptions(BuildContext context, PostModel post, bool isOwner) {
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
                      builder: (_) => PostWriteScreen(postToEdit: post),
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
                  _confirmDelete(context, post);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('사용자 차단하기'),
                onTap: () async {
                  Navigator.pop(context);
                  await showBlockDialog(
                    context,
                    ref,
                    targetUid: post.authorId,
                    targetNickname: post.authorNickname,
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
                    targetType: 'post',
                    targetId: post.id,
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

  void _confirmDelete(BuildContext context, PostModel post) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
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
              if (post.imageUrls.isNotEmpty) {
                final storage = ref.read(storageServiceProvider);
                for (final url in post.imageUrls) {
                  await storage.deleteByUrl(url);
                }
              }
              await ref.read(postRepositoryProvider).deletePost(post.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // contentBlocks를 Widget 목록으로 변환 (블로그 형식 렌더링)
  List<Widget> _buildContentBlocks(
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
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.75,
                  color: AppColors.textPrimary,
                ),
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

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final currentUid = ref.watch(currentUidProvider);
    final isLiked = currentUid != null
        ? ref
                  .watch(postLikeStatusProvider((widget.postId, currentUid)))
                  .valueOrNull ??
              false
        : false;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          postAsync.when(
            data: (post) {
              if (post == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 외부 공유 버튼 — 당장 불필요해 보여 주석 처리 (재활성화 시 복구)
                  // Builder(
                  //   builder: (btnContext) => IconButton(
                  //     icon: const Icon(Icons.share_outlined),
                  //     onPressed: () {
                  //       final body = post.body.isNotEmpty
                  //           ? post.body.substring(0, post.body.length.clamp(0, 80))
                  //           : '';
                  //       final box = btnContext.findRenderObject() as RenderBox?;
                  //       Share.share(
                  //         '${post.title}\n$body\n\n펜귄 - 만년필 잉크 커뮤니티',
                  //         sharePositionOrigin:
                  //             box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                  //       );
                  //     },
                  //   ),
                  // ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMoreOptions(
                      context,
                      post,
                      post.authorId == currentUid,
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: postAsync.when(
              data: (post) {
                if (post == null) {
                  return const Center(child: Text('게시글을 찾을 수 없습니다.'));
                }
                return GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  // ── LAYOUT A: 에디토리얼 ─────────────────────────────
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // 헤더 영역
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 카테고리 뱃지
                            if (post.category != null &&
                                post.category!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  post.category!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            // 제목 (크고 굵게)
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // by-line
                            _EditorialByline(
                              post: post,
                              currentUid: currentUid,
                            ),
                          ],
                        ),
                      ),
                      // 본문 + 이미지 영역
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 블로그 형식 (contentBlocks) ──
                            if (post.contentBlocks != null &&
                                post.contentBlocks!.isNotEmpty)
                              ..._buildContentBlocks(
                                context,
                                post.contentBlocks!,
                                post.imageUrls,
                              )
                            // ── 기존 형식 폴백 ──
                            else ...[
                              if (post.imageUrls.isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ImageViewerScreen(
                                        imageUrls: post.imageUrls,
                                        initialIndex: 0,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: post.imageUrls.first,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              LinkifiedText(
                                post.body,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.75,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (post.imageUrls.length > 1) ...[
                                const SizedBox(height: 20),
                                ...post.imageUrls
                                    .skip(1)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ImageViewerScreen(
                                                imageUrls: post.imageUrls,
                                                initialIndex: e.key + 1,
                                              ),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: e.value,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                            const SizedBox(height: 24),
                            // 좋아요 · 댓글 수
                            Row(
                              children: [
                                TapScale(
                                  onTap: currentUid != null
                                      ? () async {
                                          try {
                                            await withRetry(
                                              () => ref
                                                  .read(postRepositoryProvider)
                                                  .toggleLike(
                                                    post.id,
                                                    currentUid,
                                                    post.authorId,
                                                    !isLiked,
                                                  ),
                                            );
                                            // 마이페이지 좋아요 탭이 바로
                                            // 반영되도록 명시적으로 무효화
                                            ref.invalidate(
                                              likedPostsProvider(currentUid),
                                            );
                                          } catch (_) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('인터넷 연결을 확인해주세요'),
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 18,
                                        color: isLiked
                                            ? AppColors.error
                                            : AppColors.textTertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.likeCount}',
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: AppColors.textTertiary,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.commentCount}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // 댓글 섹션
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '댓글',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            commentsAsync.when(
                              data: (comments) => Column(
                                children: comments
                                    .map(
                                      (c) => _CommentTile(
                                        comment: c,
                                        postId: widget.postId,
                                        postAuthorId: post.authorId,
                                        currentUid: currentUid,
                                        onReplyTap: _startReply,
                                        onEditStart: () => setState(
                                          () => _hasActiveEdit = true,
                                        ),
                                        onEditEnd: () => setState(
                                          () => _hasActiveEdit = false,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── LAYOUT B: 기존 (인스타/당근 스타일) ─────────────────
                  // child: ListView(
                  //   padding: const EdgeInsets.all(16),
                  //   children: [
                  //     Text(post.title,
                  //         style: const TextStyle(
                  //             fontSize: 20, fontWeight: FontWeight.w700)),
                  //     const SizedBox(height: 12),
                  //     _PostProfileRow(post: post, currentUid: currentUid),
                  //     const Divider(height: 24),
                  //     Text(post.body,
                  //         style: const TextStyle(fontSize: 15, height: 1.6)),
                  //     if (post.imageUrls.isNotEmpty) ...[
                  //       const SizedBox(height: 16),
                  //       ...post.imageUrls.asMap().entries.map((e) => Padding(
                  //             padding: const EdgeInsets.only(bottom: 8),
                  //             child: GestureDetector(
                  //               onTap: () => Navigator.push(
                  //                 context,
                  //                 MaterialPageRoute(
                  //                   builder: (_) => ImageViewerScreen(
                  //                     imageUrls: post.imageUrls,
                  //                     initialIndex: e.key,
                  //                   ),
                  //                 ),
                  //               ),
                  //               child: ClipRRect(
                  //                 borderRadius: BorderRadius.circular(AppRadius.sm),
                  //                 child: CachedNetworkImage(
                  //                     imageUrl: e.value, fit: BoxFit.cover),
                  //               ),
                  //             ),
                  //           )),
                  //     ],
                  //     const Divider(height: 32),
                  //     Row(
                  //       children: [
                  //         GestureDetector(
                  //           behavior: HitTestBehavior.opaque,
                  //           onTap: currentUid != null
                  //               ? () async {
                  //                   try {
                  //                     await withRetry(() => ref
                  //                         .read(postRepositoryProvider)
                  //                         .toggleLike(post.id, currentUid, post.authorId));
                  //                   } catch (_) {
                  //                     if (!context.mounted) return;
                  //                     ScaffoldMessenger.of(context).showSnackBar(
                  //                       const SnackBar(
                  //                         content: Text('인터넷 연결을 확인해주세요'),
                  //                         duration: Duration(seconds: 3),
                  //                       ),
                  //                     );
                  //                   }
                  //                 }
                  //               : null,
                  //           child: Row(
                  //             mainAxisSize: MainAxisSize.min,
                  //             children: [
                  //               Icon(
                  //                 isLiked ? Icons.favorite : Icons.favorite_border,
                  //                 size: 18,
                  //                 color: isLiked ? AppColors.error : AppColors.textTertiary,
                  //               ),
                  //               const SizedBox(width: 4),
                  //               Text('${post.likeCount}',
                  //                   style: const TextStyle(
                  //                       color: AppColors.textTertiary, fontSize: 13)),
                  //             ],
                  //           ),
                  //         ),
                  //         const SizedBox(width: 16),
                  //         const Icon(Icons.chat_bubble_outline,
                  //             size: 18, color: AppColors.textTertiary),
                  //         const SizedBox(width: 4),
                  //         Text('${post.commentCount}',
                  //             style: const TextStyle(
                  //                 color: AppColors.textTertiary, fontSize: 13)),
                  //       ],
                  //     ),
                  //     const Divider(height: 24),
                  //     const Text('댓글',
                  //         style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  //     const SizedBox(height: 12),
                  //     commentsAsync.when(
                  //       data: (comments) => Column(
                  //         children: comments
                  //             .map((c) => _CommentTile(
                  //                   comment: c,
                  //                   postId: widget.postId,
                  //                   currentUid: currentUid,
                  //                   onReplyTap: _startReply,
                  //                   onEditStart: () =>
                  //                       setState(() => _hasActiveEdit = true),
                  //                   onEditEnd: () =>
                  //                       setState(() => _hasActiveEdit = false),
                  //                 ))
                  //             .toList(),
                  //       ),
                  //       loading: () => const Center(child: CircularProgressIndicator()),
                  //       error: (_, __) => const SizedBox.shrink(),
                  //     ),
                  //   ],
                  // ),
                );
              },
              loading: () =>
                  const SingleChildScrollView(child: DetailSkeleton()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
          // 댓글 입력창
          if (!_hasActiveEdit)
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_composer.replyTargetNickname != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: AppColors.chipBackground,
                      child: Row(
                        children: [
                          Text(
                            '@${_composer.replyTargetNickname} 에게 답글',
                            style: AppTextStyles.bodySmall,
                          ),
                          const Spacer(),
                          TapScale(
                            onTap: () => setState(
                              () => _composer.clearReply(clearText: true),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composer.textController,
                            focusNode: _composer.focusNode,
                            decoration: InputDecoration(
                              hintText: _composer.replyTargetNickname != null
                                  ? '답글을 입력하세요'
                                  : '댓글을 입력하세요',
                              border: InputBorder.none,
                              isDense: true,
                              counterStyle: AppTextStyles.labelSmall,
                            ),
                            maxLines: null,
                            maxLength: _composer.replyTargetNickname != null
                                ? AppConstants.maxReply
                                : AppConstants.maxComment,
                          ),
                        ),
                        _composer.isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                onPressed: _submitComment,
                                icon: const Icon(
                                  Icons.send,
                                  color: AppColors.primary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 에디토리얼 바이라인 (LAYOUT A) ────────────────────────────────────
