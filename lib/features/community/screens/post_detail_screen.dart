import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/level_system.dart';
import '../../../core/utils/network_utils.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../providers/community_provider.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/content_moderation.dart';
import '../../../shared/widgets/image_viewer_screen.dart';
import '../../../shared/widgets/common/skeletons.dart';
import 'post_write_screen.dart';

final _postAuthorProvider = FutureProvider.family<UserModel?, String>((ref, uid) {
  return ref.read(userRepoProvider).getUser(uid);
});

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _hasActiveEdit = false;
  String? _replyTargetCommentId;
  String? _replyTargetNickname;

  @override
  void dispose() {
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      if (_replyTargetCommentId != null) {
        await withRetry(() => ref.read(postRepositoryProvider).addReply(
              postId: widget.postId,
              commentId: _replyTargetCommentId!,
              reply: ReplyModel(
                id: '',
                authorId: user.uid,
                authorNickname: user.nickname,
                body: text,
                createdAt: DateTime.now(),
              ),
            ));
        setState(() {
          _replyTargetCommentId = null;
          _replyTargetNickname = null;
        });
      } else {
        await withRetry(() => ref.read(postRepositoryProvider).addComment(
              postId: widget.postId,
              authorId: user.uid,
              authorNickname: user.nickname,
              body: text,
            ));
        final levelUp = await ref
            .read(userRepoProvider)
            .addExpAndCheck(user.uid, LevelSystem.expComment);
        if (levelUp != null && mounted) {
          ref.read(levelUpProvider.notifier).state = levelUp;
        }
      }
      _commentController.clear();
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
        setState(() => _isSubmitting = false);
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _showMoreOptions(BuildContext context, PostModel post, bool isOwner) {
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
                      builder: (_) => PostWriteScreen(postToEdit: post),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('삭제', style: TextStyle(color: AppColors.error)),
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
                leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                title: const Text('신고하기',
                    style: TextStyle(color: AppColors.error)),
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
              return IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () =>
                    _showMoreOptions(context, post, post.authorId == currentUid),
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
                  child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(post.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _PostProfileRow(post: post, currentUid: currentUid),
                    const Divider(height: 24),
                    Text(post.body,
                        style: const TextStyle(fontSize: 15, height: 1.6)),
                    if (post.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...post.imageUrls.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(
                                    imageUrls: post.imageUrls,
                                    initialIndex: e.key,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                    imageUrl: e.value, fit: BoxFit.cover),
                              ),
                            ),
                          )),
                    ],
                    const Divider(height: 32),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: currentUid != null
                              ? () async {
                                  try {
                                    await withRetry(() => ref
                                        .read(postRepositoryProvider)
                                        .toggleLike(post.id, currentUid, post.authorId));
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                              Text('${post.likeCount}',
                                  style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.chat_bubble_outline,
                            size: 18, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('${post.commentCount}',
                            style: const TextStyle(
                                color: AppColors.textTertiary, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('댓글',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    commentsAsync.when(
                      data: (comments) => Column(
                        children: comments
                            .map((c) => _CommentTile(
                                  comment: c,
                                  postId: widget.postId,
                                  currentUid: currentUid,
                                  onReplyTap: _startReply,
                                  onEditStart: () => setState(
                                      () => _hasActiveEdit = true),
                                  onEditEnd: () => setState(
                                      () => _hasActiveEdit = false),
                                ))
                            .toList(),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                );
              },
              loading: () => const SingleChildScrollView(child: DetailSkeleton()),
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
                  if (_replyTargetNickname != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: AppColors.chipBackground,
                      child: Row(
                        children: [
                          Text('@$_replyTargetNickname 에게 답글',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _replyTargetCommentId = null;
                              _replyTargetNickname = null;
                              _commentController.clear();
                            }),
                            child: const Icon(Icons.close,
                                size: 16,
                                color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                          top: BorderSide(color: AppColors.divider)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: _replyTargetNickname != null
                                  ? '답글을 입력하세요'
                                  : '댓글을 입력하세요',
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                            ),
                            maxLines: null,
                            maxLength: _replyTargetNickname != null
                                ? AppConstants.maxReply
                                : AppConstants.maxComment,
                          ),
                        ),
                        _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : IconButton(
                                onPressed: _submitComment,
                                icon: const Icon(Icons.send,
                                    color: AppColors.primary),
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

// ── 작성자 프로필 행 ──────────────────────────────────────────────────
class _PostProfileRow extends ConsumerWidget {
  const _PostProfileRow({required this.post, required this.currentUid});
  final PostModel post;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(_postAuthorProvider(post.authorId));
    final isOwnPost = post.authorId == currentUid;
    final isDeletedUser = authorAsync.valueOrNull == null;
    final isFollowing = (!isOwnPost && currentUid != null && !isDeletedUser)
        ? ref
                .watch(followStatusProvider((currentUid!, post.authorId)))
                .valueOrNull ??
            false
        : false;

    return Row(
      children: [
        GestureDetector(
          onTap: () => navigateToProfile(context, ref, post.authorId),
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
            onTap: () => navigateToProfile(context, ref, post.authorId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                authorAsync.when(
                  data: (user) => Text(
                    user == null
                        ? '${post.authorNickname} (탈퇴)'
                        : user.nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
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
                    post.authorNickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(post.createdAt, locale: 'ko'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (!isOwnPost && currentUid != null && !isDeletedUser)
          isFollowing
              ? ElevatedButton(
                  onPressed: () =>
                      ref.read(userRepoProvider).unfollow(currentUid!, post.authorId),
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
                      ref.read(userRepoProvider).follow(currentUid!, post.authorId),
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
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.currentUid,
    required this.onReplyTap,
    this.onEditStart,
    this.onEditEnd,
  });
  final PostCommentModel comment;
  final String postId;
  final String? currentUid;
  final void Function(String commentId, String nickname) onReplyTap;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  bool _isEditing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.comment.body ?? '');
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  bool get _isOwn => widget.comment.authorId == widget.currentUid;

  void _showMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (_isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isEditing = true);
                  widget.onEditStart?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: const Text('삭제',
                    style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  FocusScope.of(context).unfocus();
                  await ref.read(postRepositoryProvider).deleteComment(
                      widget.postId, widget.comment.id);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('차단'),
                onTap: () async {
                  Navigator.pop(context);
                  await showBlockDialog(context, ref,
                      targetUid: widget.comment.authorId,
                      targetNickname: widget.comment.authorNickname);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: AppColors.error),
                title: const Text('신고하기',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  showReportSheet(context, ref,
                      targetType: 'comment',
                      targetId: widget.comment.id);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEdit() async {
    final newBody = _editCtrl.text.trim();
    if (newBody.isEmpty || newBody == widget.comment.body) {
      setState(() => _isEditing = false);
      widget.onEditEnd?.call();
      return;
    }
    await ref.read(postRepositoryProvider).updateComment(
        widget.postId, widget.comment.id, newBody);
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final replies = ref.watch(postRepliesProvider(
        (postId: widget.postId, commentId: widget.comment.id)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.comment.isDeleted)
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.chipBackground,
                  child: Icon(Icons.person,
                      size: 16, color: AppColors.textTertiary),
                ),
                const SizedBox(width: 10),
                const Text('삭제된 댓글입니다.',
                    style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                        fontStyle: FontStyle.italic)),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => navigateToProfile(
                      context, ref, widget.comment.authorId),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.chipBackground,
                    child: Icon(Icons.person,
                        size: 16, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => navigateToProfile(
                                context, ref, widget.comment.authorId),
                            child: Text(widget.comment.authorNickname,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              timeago.format(widget.comment.createdAt,
                                  locale: 'ko'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                          if (widget.comment.updatedAt != null) ...[
                            const SizedBox(width: 4),
                            const Text('(수정됨)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary)),
                          ],
                          const Spacer(),
                          GestureDetector(
                            onTap: () => widget.onReplyTap(
                                widget.comment.id,
                                widget.comment.authorNickname),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('답글',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showMenu,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.more_vert,
                                  size: 16,
                                  color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (_isEditing) ...[
                        TextField(
                          controller: _editCtrl,
                          autofocus: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            counterText: '',
                          ),
                          maxLines: null,
                          maxLength: AppConstants.maxComment,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _editCtrl.text = widget.comment.body ?? '';
                                });
                                widget.onEditEnd?.call();
                              },
                              child: const Text('취소'),
                            ),
                            TextButton(
                                onPressed: _saveEdit,
                                child: const Text('저장')),
                          ],
                        ),
                      ] else ...[
                        Text(widget.comment.body ?? '',
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          replies.when(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: 36, top: 6),
                    child: Column(
                      children: list
                          .map((r) => _PostReplyTile(
                                reply: r,
                                postId: widget.postId,
                                commentId: widget.comment.id,
                                currentUid: widget.currentUid,
                                onReplyTap: () => widget.onReplyTap(
                                    widget.comment.id, r.authorNickname),
                                onEditStart: widget.onEditStart,
                                onEditEnd: widget.onEditEnd,
                              ))
                          .toList(),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PostReplyTile extends ConsumerStatefulWidget {
  const _PostReplyTile({
    required this.reply,
    required this.postId,
    required this.commentId,
    required this.currentUid,
    required this.onReplyTap,
    this.onEditStart,
    this.onEditEnd,
  });
  final ReplyModel reply;
  final String postId;
  final String commentId;
  final String? currentUid;
  final VoidCallback onReplyTap;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  ConsumerState<_PostReplyTile> createState() => _PostReplyTileState();
}

class _PostReplyTileState extends ConsumerState<_PostReplyTile> {
  bool _isEditing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.reply.body ?? '');
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  bool get _isOwn => widget.reply.authorId == widget.currentUid;

  void _showMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (_isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isEditing = true);
                  widget.onEditStart?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: const Text('삭제',
                    style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  FocusScope.of(context).unfocus();
                  await ref.read(postRepositoryProvider).deleteReply(
                      widget.postId, widget.commentId, widget.reply.id);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('차단'),
                onTap: () async {
                  Navigator.pop(context);
                  await showBlockDialog(context, ref,
                      targetUid: widget.reply.authorId,
                      targetNickname: widget.reply.authorNickname);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: AppColors.error),
                title: const Text('신고하기',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  showReportSheet(context, ref,
                      targetType: 'reply', targetId: widget.reply.id);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEdit() async {
    final newBody = _editCtrl.text.trim();
    if (newBody.isEmpty || newBody == widget.reply.body) {
      setState(() => _isEditing = false);
      widget.onEditEnd?.call();
      return;
    }
    await ref.read(postRepositoryProvider).updateReply(
        widget.postId, widget.commentId, widget.reply.id, newBody);
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                navigateToProfile(context, ref, widget.reply.authorId),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.chipBackground,
              child: Icon(Icons.person,
                  size: 14, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => navigateToProfile(
                          context, ref, widget.reply.authorId),
                      child: Text(widget.reply.authorNickname,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        timeago.format(widget.reply.createdAt,
                            locale: 'ko'),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary)),
                    if (widget.reply.updatedAt != null) ...[
                      const SizedBox(width: 4),
                      const Text('(수정됨)',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary)),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: _showMenu,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_vert,
                            size: 16, color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (_isEditing) ...[
                  TextField(
                    controller: _editCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      counterText: '',
                    ),
                    maxLines: null,
                    maxLength: AppConstants.maxReply,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _editCtrl.text = widget.reply.body ?? '';
                          });
                          widget.onEditEnd?.call();
                        },
                        child: const Text('취소'),
                      ),
                      TextButton(
                          onPressed: _saveEdit,
                          child: const Text('저장')),
                    ],
                  ),
                ] else ...[
                  Text(widget.reply.body ?? '',
                      style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
