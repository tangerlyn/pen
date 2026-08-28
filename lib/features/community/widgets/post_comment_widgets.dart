part of '../screens/post_detail_screen.dart';

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.postAuthorId,
    required this.currentUid,
    required this.onReplyTap,
    this.onEditStart,
    this.onEditEnd,
  });
  final PostCommentModel comment;
  final String postId;
  final String postAuthorId;
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
  bool get _isPostAuthor => widget.comment.authorId == widget.postAuthorId;

  void _showMenu() {
    FocusScope.of(context).unfocus();
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
                      .read(postRepositoryProvider)
                      .deleteComment(widget.postId, widget.comment.id);
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
                    targetNickname: widget.comment.authorNickname,
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
        .read(postRepositoryProvider)
        .updateComment(widget.postId, widget.comment.id, newBody);
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final replies = ref.watch(
      postRepliesProvider((
        postId: widget.postId,
        commentId: widget.comment.id,
      )),
    );
    final author = ref
        .watch(_postAuthorProvider(widget.comment.authorId))
        .valueOrNull;
    final authorLevel = author?.level ?? widget.comment.authorLevel;
    final profileImageUrl = author?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.comment.isDeleted)
            Row(
              children: [
                const UserAvatar(radius: 16),
                const SizedBox(width: 10),
                Text(
                  '삭제된 댓글입니다.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TapScale(
                  onTap: () =>
                      navigateToProfile(context, ref, widget.comment.authorId),
                  child: UserAvatar(imageUrl: profileImageUrl, radius: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: TapScale(
                              onTap: () => navigateToProfile(
                                context,
                                ref,
                                widget.comment.authorId,
                              ),
                              child: Text(
                                widget.comment.authorNickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          LevelBadge(authorLevel),
                          if (_isPostAuthor) ...[
                            const SizedBox(width: 6),
                            const AuthorBadge(),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            formatPostDate(widget.comment.createdAt),
                            style: AppTextStyles.labelSmall,
                          ),
                          if (widget.comment.updatedAt != null) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '(수정됨)',
                              style: AppTextStyles.labelSmall,
                            ),
                          ],
                          const SizedBox(width: 8),
                          TapScale(
                            onTap: () => widget.onReplyTap(
                              widget.comment.id,
                              widget.comment.authorNickname,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('답글', style: AppTextStyles.bodySmall),
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
                      const SizedBox(height: 3),
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
                            counterStyle: AppTextStyles.labelSmall,
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
                              child: const Text('저장'),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          widget.comment.body ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
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
                          .map(
                            (r) => _PostReplyTile(
                              reply: r,
                              postId: widget.postId,
                              postAuthorId: widget.postAuthorId,
                              commentId: widget.comment.id,
                              currentUid: widget.currentUid,
                              onReplyTap: () => widget.onReplyTap(
                                widget.comment.id,
                                r.authorNickname,
                              ),
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
}

class _PostReplyTile extends ConsumerStatefulWidget {
  const _PostReplyTile({
    required this.reply,
    required this.postId,
    required this.postAuthorId,
    required this.commentId,
    required this.currentUid,
    required this.onReplyTap,
    this.onEditStart,
    this.onEditEnd,
  });
  final ReplyModel reply;
  final String postId;
  final String postAuthorId;
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
  bool get _isPostAuthor => widget.reply.authorId == widget.postAuthorId;

  void _showMenu() {
    FocusScope.of(context).unfocus();
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
                      .read(postRepositoryProvider)
                      .deleteReply(
                        widget.postId,
                        widget.commentId,
                        widget.reply.id,
                      );
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
        .read(postRepositoryProvider)
        .updateReply(widget.postId, widget.commentId, widget.reply.id, newBody);
    setState(() => _isEditing = false);
    widget.onEditEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final author = ref
        .watch(_postAuthorProvider(widget.reply.authorId))
        .valueOrNull;
    final authorLevel = author?.level ?? widget.reply.authorLevel;
    final profileImageUrl = author?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TapScale(
            onTap: () => navigateToProfile(context, ref, widget.reply.authorId),
            child: UserAvatar(imageUrl: profileImageUrl, radius: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: TapScale(
                        onTap: () => navigateToProfile(
                          context,
                          ref,
                          widget.reply.authorId,
                        ),
                        child: Text(
                          widget.reply.authorNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    LevelBadge(authorLevel),
                    if (_isPostAuthor) ...[
                      const SizedBox(width: 6),
                      const AuthorBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      formatPostDate(widget.reply.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                    if (widget.reply.updatedAt != null) ...[
                      const SizedBox(width: 4),
                      const Text('(수정됨)', style: AppTextStyles.labelSmall),
                    ],
                    const SizedBox(width: 8),
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
                const SizedBox(height: 3),
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
                      counterStyle: AppTextStyles.labelSmall,
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
                      TextButton(onPressed: _saveEdit, child: const Text('저장')),
                    ],
                  ),
                ] else ...[
                  Text(
                    widget.reply.body ?? '',
                    style: const TextStyle(fontSize: 14),
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
