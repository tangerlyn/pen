import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/editor/blog_body_editor.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../shared/widgets/confirm_discard_dialog.dart';
import '../providers/community_provider.dart';
import '../../../data/models/post_model.dart';

class PostWriteScreen extends ConsumerStatefulWidget {
  const PostWriteScreen({super.key, this.postToEdit});
  final PostModel? postToEdit;

  @override
  ConsumerState<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends ConsumerState<PostWriteScreen> {
  late final TextEditingController _titleController;
  String? _selectedCategory;
  bool _isSubmitting = false;
  final _editorKey = GlobalKey<BlogBodyEditorState>();
  List<EditorBlock>? _initialEditorBlocks;
  // 에디터가 초기 블록 인스턴스를 그대로 고쳐 쓰므로, 시작 시점 내용을 따로 남겨 둔다
  String? _initialBlocksSignature;
  bool _showEditorToolbar = false;

  bool get _isEditing => widget.postToEdit != null;

  @override
  void initState() {
    super.initState();
    final post = widget.postToEdit;
    _titleController = TextEditingController(text: post?.title ?? '');
    _selectedCategory = post?.category;

    if (post != null) {
      if (post.contentBlocks != null && post.contentBlocks!.isNotEmpty) {
        _initialEditorBlocks = editorBlocksFromMap(post.contentBlocks!);
      } else {
        _initialEditorBlocks = editorBlocksFromLegacy(
          body: post.body,
          imageUrls: post.imageUrls,
        );
      }
      _initialBlocksSignature = _blocksSignature(_initialEditorBlocks!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCenterToast(context, message: '제목을 입력해주세요.');
      return;
    }

    final editorState = _editorKey.currentState;
    if (editorState == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      // 이미지 업로드 + contentBlocks 빌드
      List<Map<String, dynamic>> contentBlocks;
      try {
        contentBlocks = await editorState.buildContentBlocks(
          uploadImage: (file) => ref
              .read(storageServiceProvider)
              .uploadImage(file: file, folder: 'posts'),
        );
      } catch (_) {
        if (mounted) {
          showCenterToast(
            context,
            message: '이미지 업로드에 실패했어요. 다시 시도해주세요.',
            icon: Icons.error_outline,
            iconColor: const Color(0xFFE53935),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      final imageUrls = contentBlocks
          .where((b) => b['type'] == 'image')
          .map((b) => b['url'] as String)
          .toList();
      final body = contentBlocks
          .where((b) => b['type'] == 'text')
          .map((b) => b['content'] as String)
          .join('\n');

      if (_isEditing) {
        await withRetry(
          () => ref
              .read(postRepositoryProvider)
              .updatePost(widget.postToEdit!.id, {
                'title': title,
                'body': body,
                'imageUrls': imageUrls,
                'contentBlocks': contentBlocks,
                'category': _selectedCategory,
              }),
        );
        if (mounted) {
          ref.invalidate(communityFeedProvider);
          context.pop();
        }
      } else {
        final postId = await withRetry(
          () => ref
              .read(postWriteProvider.notifier)
              .submit(
                authorId: user.uid,
                authorNickname: user.nickname,
                authorLevel: user.level,
                title: title,
                body: body,
                imageUrls: imageUrls,
                category: _selectedCategory,
                contentBlocks: contentBlocks,
              ),
        );
        if (mounted) {
          context.pop();
          context.push('/community/$postId');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? '게시글을 수정하지 못했어요. 잠시 후 다시 시도해 주세요.'
                  : '게시글을 올리지 못했어요. 잠시 후 다시 시도해 주세요.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _hasContent() {
    if (_isEditing) return _hasEditChanges();
    if (_titleController.text.isNotEmpty) return true;
    if (_selectedCategory != null) return true;
    final blocks = _editorKey.currentState?.getBlocks() ?? [];
    return blocks.any((b) {
      if (b is TextEditorBlock) return b.controller.text.isNotEmpty;
      if (b is ImageEditorBlock) return true;
      return false;
    });
  }

  /// 수정 모드: 제목·카테고리·본문 블록이 원래 글과 달라졌는지
  bool _hasEditChanges() {
    final post = widget.postToEdit!;
    if (_titleController.text.trim() != post.title.trim()) return true;
    if (_selectedCategory != post.category) return true;
    final current = _editorKey.currentState?.getBlocks();
    if (current == null) return false;
    return _blocksSignature(current) != _initialBlocksSignature;
  }

  /// 블록 목록을 비교용 문자열로 만든다 (텍스트는 내용, 이미지는 URL/파일 경로)
  String _blocksSignature(List<EditorBlock> blocks) => blocks
      .map((b) {
        if (b is TextEditorBlock) return 't:${b.controller.text.trim()}';
        if (b is ImageEditorBlock) return 'i:${b.url ?? b.file?.path}';
        return '';
      })
      .where((s) => s != 't:')
      .join('\u0000');

  Future<bool> _confirmDiscard() async {
    if (!_hasContent()) return true;
    if (_isEditing) {
      return confirmDiscardDialog(
        context,
        title: '수정 중인 내용이 있어요',
        content: '지금 나가면 수정한 내용이 저장되지 않아요.',
        cancelLabel: '계속 수정',
        confirmLabel: '나가기',
      );
    }
    return confirmDiscardDialog(context, confirmLabel: '삭제하고 나가기');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '게시글 수정' : '글쓰기'),
          actions: [
            _isSubmitting
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: Text(
                      _isEditing ? '수정' : '등록',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              // 카테고리 선택
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: ['질문', '정보공유', '필사', '그림'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(
                        () => _selectedCategory = isSelected ? null : cat,
                      ),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '제목',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLength: AppConstants.maxPostTitle,
                ),
              ),
              const SizedBox(height: 4),
              // 블로그 에디터 (본문 + 인라인 이미지)
              BlogBodyEditor(
                key: _editorKey,
                hintText: '내용을 입력하세요',
                initialBlocks: _initialEditorBlocks,
                maxTextLength: AppConstants.maxPostBody,
                onFocusChanged: (hasFocus) =>
                    setState(() => _showEditorToolbar = hasFocus),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _showEditorToolbar
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: BlogEditorToolbar(editorKey: _editorKey),
              )
            : null,
      ),
    );
  }
}
