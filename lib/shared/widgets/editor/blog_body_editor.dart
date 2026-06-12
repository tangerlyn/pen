import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

// ── Editor block types ────────────────────────────────────────
sealed class EditorBlock {}

class TextEditorBlock extends EditorBlock {
  TextEditorBlock({String initial = ''})
      : controller = TextEditingController(text: initial),
        focusNode = FocusNode();
  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class ImageEditorBlock extends EditorBlock {
  ImageEditorBlock({this.file, this.url});
  final File? file;
  final String? url;
}

// ── Helpers: Firestore ↔ EditorBlock ─────────────────────────
List<EditorBlock> editorBlocksFromMap(List<Map<String, dynamic>> maps) =>
    maps.map<EditorBlock>((m) {
      if (m['type'] == 'image') return ImageEditorBlock(url: m['url'] as String?);
      return TextEditorBlock(initial: m['content'] as String? ?? '');
    }).toList();

// 기존 body + imageUrls → 블록 목록 (하위 호환)
List<EditorBlock> editorBlocksFromLegacy({
  required String body,
  required List<String> imageUrls,
}) {
  if (imageUrls.isEmpty) return [TextEditorBlock(initial: body)];
  return [
    TextEditorBlock(initial: body),
    ...imageUrls.map((url) => ImageEditorBlock(url: url)),
    TextEditorBlock(),
  ];
}

// ── Blog editor widget ────────────────────────────────────────
class BlogBodyEditor extends StatefulWidget {
  const BlogBodyEditor({
    super.key,
    this.hintText = '내용을 입력하세요',
    this.initialBlocks,
    this.maxTextLength,
  });

  final String hintText;
  final List<EditorBlock>? initialBlocks;
  final int? maxTextLength;

  @override
  State<BlogBodyEditor> createState() => BlogBodyEditorState();
}

class BlogBodyEditorState extends State<BlogBodyEditor> {
  late List<EditorBlock> _blocks;

  @override
  void initState() {
    super.initState();
    final init = widget.initialBlocks;
    _blocks = (init != null && init.isNotEmpty) ? List.from(init) : [TextEditorBlock()];
  }

  @override
  void dispose() {
    for (final b in _blocks) {
      if (b is TextEditorBlock) b.dispose();
    }
    super.dispose();
  }

  List<EditorBlock> getBlocks() => List.unmodifiable(_blocks);

  /// 이미지 블록은 업로드하고, Firestore 저장 가능한 Map 목록 반환.
  Future<List<Map<String, dynamic>>> buildContentBlocks({
    required Future<String> Function(File file) uploadImage,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (final block in _blocks) {
      if (block is TextEditorBlock) {
        final text = block.controller.text.trim();
        if (text.isNotEmpty) result.add({'type': 'text', 'content': text});
      } else if (block is ImageEditorBlock) {
        String? url = block.url;
        if (url == null && block.file != null) url = await uploadImage(block.file!);
        if (url != null && url.isNotEmpty) result.add({'type': 'image', 'url': url});
      }
    }
    return result;
  }

  Future<void> _insertImageAfter(int blockIndex) async {
    final picker = ImagePicker();
    final xfiles = await picker.pickMultiImage(imageQuality: 85);
    if (xfiles.isEmpty || !mounted) return;
    setState(() {
      int insertAt = blockIndex + 1;
      for (final xf in xfiles) {
        _blocks.insert(insertAt, ImageEditorBlock(file: File(xf.path)));
        insertAt++;
      }
      if (_blocks.last is! TextEditorBlock) _blocks.add(TextEditorBlock());
    });
  }

  void _removeBlock(int index) {
    final b = _blocks[index];
    if (b is TextEditorBlock) b.dispose();
    setState(() {
      _blocks.removeAt(index);
      if (_blocks.isEmpty) _blocks.add(TextEditorBlock());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _blocks.length; i++) ...[
          _buildBlock(i),
          _InsertImageButton(onTap: () => _insertImageAfter(i)),
        ],
      ],
    );
  }

  Widget _buildBlock(int i) {
    final block = _blocks[i];
    if (block is TextEditorBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          maxLines: null,
          maxLength: widget.maxTextLength,
          decoration: InputDecoration(
            hintText: i == 0 ? widget.hintText : null,
            border: InputBorder.none,
            counterText: '',
          ),
          style: const TextStyle(fontSize: 15, height: 1.75),
        ),
      );
    }
    if (block is ImageEditorBlock) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: block.url != null
                  ? CachedNetworkImage(
                      imageUrl: block.url!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      block.file!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeBlock(i),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _InsertImageButton extends StatelessWidget {
  const _InsertImageButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_photo_alternate_outlined, size: 15, color: AppColors.textTertiary),
            SizedBox(width: 4),
            Text('사진 삽입', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
