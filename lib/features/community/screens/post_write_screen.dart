import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_utils.dart';
import '../../../shared/providers/providers.dart';
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
  late final TextEditingController _bodyController;
  final List<XFile> _pickedImages = [];
  late List<String> _existingImageUrls;
  String? _selectedCategory;
  bool _isSubmitting = false;

  bool get _isEditing => widget.postToEdit != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.postToEdit?.title ?? '');
    _bodyController = TextEditingController(text: widget.postToEdit?.body ?? '');
    _existingImageUrls = List<String>.from(widget.postToEdit?.imageUrls ?? []);
    _selectedCategory = widget.postToEdit?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _pickedImages.addAll(images));
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
      );
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      List<String> newImageUrls = [];
      if (_pickedImages.isNotEmpty) {
        try {
          final storage = ref.read(storageServiceProvider);
          for (final img in _pickedImages) {
            final url = await withRetry(
              () => storage.uploadImage(file: File(img.path), folder: 'posts'),
            );
            newImageUrls.add(url);
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이미지 업로드에 실패했어요. 다시 시도해주세요.'),
                backgroundColor: Color(0xFFE53935),
                duration: Duration(seconds: 3),
              ),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }
      }

      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      if (_isEditing) {
        await withRetry(() => ref.read(postRepositoryProvider).updatePost(
          widget.postToEdit!.id,
          {'title': title, 'body': body, 'imageUrls': allImageUrls},
        ));
        if (mounted) context.pop();
      } else {
        final postId = await withRetry(() => ref.read(postWriteProvider.notifier).submit(
              authorId: user.uid,
              authorNickname: user.nickname,
              title: title,
              body: body,
              imageUrls: allImageUrls,
              category: _selectedCategory,
            ));
        if (mounted && postId != null) {
          context.pop();
          context.push('/community/$postId');
        }
      }
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '게시글 수정' : '글쓰기'),
        actions: [
          _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _submit,
                  child: Text(
                    _isEditing ? '수정' : '등록',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: ['질문', '정보공유'].map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => setState(
                  () => _selectedCategory = isSelected ? null : cat,
                ),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: '제목', border: InputBorder.none, counterText: ''),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            maxLength: AppConstants.maxPostTitle,
          ),
          const Divider(),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(hintText: '내용을 입력하세요', border: InputBorder.none, counterText: ''),
            maxLines: null,
            minLines: 10,
            maxLength: AppConstants.maxPostBody,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 16),
          // 기존 이미지 (수정 시)
          if (_existingImageUrls.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _existingImageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_existingImageUrls[i], width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _existingImageUrls.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 새로 추가된 이미지
          if (_pickedImages.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_pickedImages[i].path), width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_outlined),
            label: const Text('사진 첨부'),
          ),
        ],
      ),
    );
  }
}
