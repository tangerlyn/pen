import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../center_toast.dart';


// ── Editor block types ────────────────────────────────────────
sealed class EditorBlock {}

class TextEditorBlock extends EditorBlock {
  // 컨트롤러 생성자에 text만 넘기면 selection이 기본으로 offset: -1(무효)이 되어
  // 처음 포커스를 줄 때 텍스트가 순간적으로 사라지는 것처럼 보이는 문제가 있어서,
  // 커서를 텍스트 끝으로 명시적으로 지정해줌
  TextEditorBlock({String initial = ''})
      : controller = TextEditingController(text: initial)
          ..selection = TextSelection.collapsed(offset: initial.length),
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
    this.onFocusChanged,
  });

  final String hintText;
  final List<EditorBlock>? initialBlocks;
  final int? maxTextLength;
  /// 본문 텍스트 블록 중 하나라도 포커스를 갖게/잃게 될 때 호출됨.
  /// 키보드 위 툴바를 본문 입력 중에만 보여주기 위한 용도.
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<BlogBodyEditor> createState() => BlogBodyEditorState();
}

class BlogBodyEditorState extends State<BlogBodyEditor> {
  late List<EditorBlock> _blocks;
  TextEditorBlock? _focusedBlock;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialBlocks;
    _blocks = (init != null && init.isNotEmpty) ? List.from(init) : [TextEditorBlock()];
    for (final b in _blocks) {
      if (b is TextEditorBlock) _attachFocusListener(b);
    }
  }

  void _attachFocusListener(TextEditorBlock block) {
    block.focusNode.addListener(() {
      if (!mounted) return;
      if (block.focusNode.hasFocus) _focusedBlock = block;
      final hasFocus = _blocks.any((b) => b is TextEditorBlock && b.focusNode.hasFocus);
      if (hasFocus != _hasFocus) {
        _hasFocus = hasFocus;
        widget.onFocusChanged?.call(hasFocus);
      }
    });
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

  /// 툴바의 "사진" 버튼 — 갤러리에서 여러 장 선택해 커서 위치에 삽입.
  Future<void> insertImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final xfiles = await picker.pickMultiImage(imageQuality: 85);
      if (xfiles.isEmpty || !mounted) return;
      _insertImages(xfiles.map((xf) => File(xf.path)).toList());
    } catch (_) {
      if (mounted) showCenterToast(context, message: '사진을 불러오지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 툴바의 "카메라" 버튼 — 촬영한 사진 1장을 커서 위치에 삽입.
  Future<void> insertImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (xfile == null || !mounted) return;
      _insertImages([File(xfile.path)]);
    } catch (_) {
      if (mounted) showCenterToast(context, message: '사진을 불러오지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 포커스된 텍스트 블록의 커서 위치에서 글을 나누고 그 사이에 사진을 끼워 넣는다.
  /// 삽입 후에는 사진 바로 뒤 블록으로 포커스를 옮겨, 한 칸에서 계속 이어 쓰는 것처럼 느껴지게 한다.
  void _insertImages(List<File> files) {
    late final TextEditorBlock focusTarget;
    setState(() {
      final focused = _focusedBlock;
      int insertAt;
      String? splitOffText;

      if (focused != null && _blocks.contains(focused)) {
        final idx = _blocks.indexOf(focused);
        final text = focused.controller.text;
        if (text.isEmpty) {
          // 빈 블록(예: 아무것도 안 쓴 채 바로 사진부터 삽입)은 그 자리에서 없애고
          // 사진으로 대체한다 — 안 그러면 빈 블록이 남아 힌트 텍스트가 계속 보임.
          focused.dispose();
          if (identical(_focusedBlock, focused)) _focusedBlock = null;
          _blocks.removeAt(idx);
          insertAt = idx;
        } else {
          final cursor = focused.controller.selection.baseOffset;
          if (cursor >= 0 && cursor < text.length) {
            // 커서가 텍스트 중간에 있으면 그 자리에서 잘라 사진 뒤로 이어붙인다.
            focused.controller.text = text.substring(0, cursor);
            splitOffText = text.substring(cursor);
          }
          insertAt = idx + 1;
        }
      } else {
        insertAt = _blocks.length;
      }

      for (final file in files) {
        _blocks.insert(insertAt, ImageEditorBlock(file: file));
        insertAt++;
      }

      final next = insertAt < _blocks.length ? _blocks[insertAt] : null;
      if (splitOffText != null) {
        final newBlock = TextEditorBlock(initial: splitOffText);
        _attachFocusListener(newBlock);
        _blocks.insert(insertAt, newBlock);
        focusTarget = newBlock;
      } else if (next is TextEditorBlock) {
        focusTarget = next;
      } else {
        final newBlock = TextEditorBlock();
        _attachFocusListener(newBlock);
        _blocks.insert(insertAt, newBlock);
        focusTarget = newBlock;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusTarget.focusNode.requestFocus();
      focusTarget.controller.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  /// 사진 블록을 지운다. 지운 자리의 앞뒤가 둘 다 텍스트 블록이면 하나로 이어붙여
  /// 사진이 애초에 없었던 것처럼 한 단락으로 되돌린다.
  void _removeBlock(int index) {
    final removed = _blocks[index];
    setState(() {
      if (removed is TextEditorBlock) {
        removed.dispose();
        if (identical(_focusedBlock, removed)) _focusedBlock = null;
      }
      _blocks.removeAt(index);

      if (index > 0 && index < _blocks.length) {
        final prev = _blocks[index - 1];
        final next = _blocks[index];
        if (prev is TextEditorBlock && next is TextEditorBlock) {
          prev.controller.text += next.controller.text;
          next.dispose();
          if (identical(_focusedBlock, next)) _focusedBlock = prev;
          _blocks.removeAt(index);
        }
      }

      if (_blocks.isEmpty) {
        final newBlock = TextEditorBlock();
        _attachFocusListener(newBlock);
        _blocks.add(newBlock);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _blocks.length; i++) _buildBlock(i),
        ],
      ),
    );
  }

  Widget _buildBlock(int i) {
    final block = _blocks[i];
    if (block is TextEditorBlock) {
      return Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 4, bottom: 4),
        child: TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          maxLines: null,
          maxLength: widget.maxTextLength,
          decoration: InputDecoration(
            hintText: i == 0 ? widget.hintText : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            counterText: '',
          ),
          style: const TextStyle(fontSize: 15, height: 1.75),
        ),
      );
    }
    if (block is ImageEditorBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
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

// ── 키보드 위 고정 툴바 (네이버 블로그 스타일) ────────────────
/// 본문 텍스트 블록이 포커스를 가진 동안에만(`BlogBodyEditor.onFocusChanged` 기준)
/// `bottomNavigationBar`에 조건부로 올리고, 키보드 높이(`MediaQuery.viewInsets.bottom`)만큼
/// 바깥에서 Padding을 줘서 키보드 바로 위에 붙인다. (bottomNavigationBar는 키보드를
/// 따라 자동으로 올라오지 않으므로 직접 오프셋을 줘야 함)
class BlogEditorToolbar extends StatelessWidget {
  const BlogEditorToolbar({super.key, required this.editorKey});
  final GlobalKey<BlogBodyEditorState> editorKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFEFEF), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          _ToolbarIconButton(
            icon: Icons.camera_alt_outlined,
            onTap: () => editorKey.currentState?.insertImageFromCamera(),
          ),
          const SizedBox(width: 20),
          _ToolbarIconButton(
            icon: Icons.photo_outlined,
            onTap: () => editorKey.currentState?.insertImagesFromGallery(),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: AppColors.textSecondary,
      onPressed: onTap,
    );
  }
}
