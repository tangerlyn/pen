import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/models/review_model.dart';
import '../../../data/models/reply_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../providers/providers.dart';
import '../../../features/home/providers/review_detail_provider.dart';
import '../content_moderation.dart';
import '../level_badge.dart';
import '../author_badge.dart';
import '../../../data/models/user_model.dart';
import '../tap_scale.dart';

final _commentAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

class CommentTile extends ConsumerStatefulWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.reviewId,
    required this.reviewAuthorId,
    required this.currentUid,
    required this.onReplyTap,
    this.onDeleted,
    this.onReplyDeleted,
    this.onEditStart,
    this.onEditEnd,
  });

  final CommentModel comment;
  final String reviewId;
  final String reviewAuthorId;
  final String? currentUid;
  final void Function(String commentId, String nickname) onReplyTap;
  final VoidCallback? onDeleted;
  final VoidCallback? onReplyDeleted;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> {
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
  bool get _isPostAuthor => widget.comment.authorId == widget.reviewAuthorId;
  String get _nickname => widget.comment.authorNickname.isNotEmpty
      ? widget.comment.authorNickname
      : widget.comment.authorId;

  void _showMenu() {
    FocusScope.of(context).unfocus();
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
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  '삭제',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (!mounted) return;
                  FocusScope.of(context).unfocus();
                  await ref
                      .read(reviewRepoProvider)
                      .deleteComment(widget.reviewId, widget.comment.id);
                  widget.onDeleted?.call();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('차단'),
                onTap: () async {
                  Navigator.pop(context);
                  await showBlockDialog(
                    context,
                    ref,
                    targetUid: widget.comment.authorId,
                    targetNickname: _nickname,
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
                    targetType: 'comment',
                    targetId: widget.comment.id,
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

  Future<void> _saveEdit() async {
    final newBody = _editCtrl.text.trim();
    if (newBody.isEmpty || newBody == widget.comment.body) {
      setState(() => _isEditing = false);
      widget.onEditEnd?.call();
      return;
    }
    await ref
        .read(reviewRepoProvider)
        .updateComment(widget.reviewId, widget.comment.id, newBody);
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final replies = ref.watch(
      reviewRepliesProvider((
        reviewId: widget.reviewId,
        commentId: widget.comment.id,
      )),
    );
    final author = ref
        .watch(_commentAuthorProvider(widget.comment.authorId))
        .valueOrNull;
    final authorLevel = author?.level ?? widget.comment.authorLevel;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.comment.isDeleted)
            _buildDeletedRow()
          else
            _buildActiveRow(context, authorLevel, author?.profileImageUrl),
          replies.when(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: 36, top: 6),
                    child: Column(
                      children: list
                          .map(
                            (r) => _ReplyTile(
                              reply: r,
                              reviewId: widget.reviewId,
                              reviewAuthorId: widget.reviewAuthorId,
                              commentId: widget.comment.id,
                              currentUid: widget.currentUid,
                              onReplyTap: () => widget.onReplyTap(
                                widget.comment.id,
                                r.authorNickname,
                              ),
                              onDeleted: widget.onReplyDeleted,
                              onEditStart: widget.onEditStart,
                              onEditEnd: widget.onEditEnd,
                            ),
                          )
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

  Widget _buildDeletedRow() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.chipBackground,
          child: Icon(Icons.person, size: 16, color: AppColors.textTertiary),
        ),
        const SizedBox(width: 10),
        const Text(
          '삭제된 댓글입니다.',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRow(
    BuildContext context,
    int currentLevel,
    String? profileImageUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapScale(
          onTap: () => navigateToProfile(context, ref, widget.comment.authorId),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.chipBackground,
            backgroundImage:
                (profileImageUrl != null && profileImageUrl.isNotEmpty)
                ? CachedNetworkImageProvider(profileImageUrl)
                : null,
            child: (profileImageUrl == null || profileImageUrl.isEmpty)
                ? const Icon(
                    Icons.person,
                    size: 16,
                    color: AppColors.textTertiary,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TapScale(
                    onTap: () => navigateToProfile(
                      context,
                      ref,
                      widget.comment.authorId,
                    ),
                    child: Text(
                      _nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  LevelBadge(currentLevel),
                  if (_isPostAuthor) ...[
                    const SizedBox(width: 6),
                    const AuthorBadge(),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    timeago.format(widget.comment.createdAt, locale: 'ko'),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  if (widget.comment.updatedAt != null) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '(수정됨)',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TapScale(
                    onTap: () =>
                        widget.onReplyTap(widget.comment.id, _nickname),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        '답글',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  TapScale(
                    onTap: _showMenu,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_isEditing) ...[
                TextField(
                  controller: _editCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  maxLines: null,
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
                    TextButton(onPressed: _saveEdit, child: const Text('저장')),
                  ],
                ),
              ] else ...[
                Text(
                  widget.comment.body ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── 답글 타일 ──────────────────────────────────────────────────
class _ReplyTile extends ConsumerStatefulWidget {
  const _ReplyTile({
    required this.reply,
    required this.reviewId,
    required this.reviewAuthorId,
    required this.commentId,
    required this.currentUid,
    required this.onReplyTap,
    this.onDeleted,
    this.onEditStart,
    this.onEditEnd,
  });

  final ReplyModel reply;
  final String reviewId;
  final String reviewAuthorId;
  final String commentId;
  final String? currentUid;
  final VoidCallback onReplyTap;
  final VoidCallback? onDeleted;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  ConsumerState<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends ConsumerState<_ReplyTile> {
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
  bool get _isPostAuthor => widget.reply.authorId == widget.reviewAuthorId;

  void _showMenu() {
    FocusScope.of(context).unfocus();
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
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  '삭제',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (!mounted) return;
                  FocusScope.of(context).unfocus();
                  await ref
                      .read(reviewRepoProvider)
                      .deleteReply(
                        widget.reviewId,
                        widget.commentId,
                        widget.reply.id,
                      );
                  widget.onDeleted?.call();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('차단'),
                onTap: () async {
                  Navigator.pop(context);
                  await showBlockDialog(
                    context,
                    ref,
                    targetUid: widget.reply.authorId,
                    targetNickname: widget.reply.authorNickname,
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
                    targetType: 'reply',
                    targetId: widget.reply.id,
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

  Future<void> _saveEdit() async {
    final newBody = _editCtrl.text.trim();
    if (newBody.isEmpty || newBody == widget.reply.body) {
      setState(() => _isEditing = false);
      widget.onEditEnd?.call();
      return;
    }
    await ref
        .read(reviewRepoProvider)
        .updateReply(
          widget.reviewId,
          widget.commentId,
          widget.reply.id,
          newBody,
        );
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final author = ref
        .watch(_commentAuthorProvider(widget.reply.authorId))
        .valueOrNull;
    final currentLevel = author?.level ?? widget.reply.authorLevel;
    final profileImageUrl = author?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TapScale(
            onTap: () => navigateToProfile(context, ref, widget.reply.authorId),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.chipBackground,
              backgroundImage:
                  (profileImageUrl != null && profileImageUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(profileImageUrl)
                  : null,
              child: (profileImageUrl == null || profileImageUrl.isEmpty)
                  ? const Icon(
                      Icons.person,
                      size: 14,
                      color: AppColors.textTertiary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TapScale(
                      onTap: () => navigateToProfile(
                        context,
                        ref,
                        widget.reply.authorId,
                      ),
                      child: Text(
                        widget.reply.authorNickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    LevelBadge(currentLevel),
                    if (_isPostAuthor) ...[
                      const SizedBox(width: 6),
                      const AuthorBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(widget.reply.createdAt, locale: 'ko'),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    if (widget.reply.updatedAt != null) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '(수정됨)',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const Spacer(),
                    TapScale(
                      onTap: _showMenu,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_isEditing) ...[
                  TextField(
                    controller: _editCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    maxLines: null,
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
                      TextButton(onPressed: _saveEdit, child: const Text('저장')),
                    ],
                  ),
                ] else ...[
                  Text(
                    widget.reply.body ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
