import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../shared/widgets/confirm_discard_dialog.dart';
import '../../../shared/widgets/editor/blog_body_editor.dart';
import '../providers/ink_shape_provider.dart';
import '../widgets/ink_add_success_overlay.dart';
import '../widgets/ink_swatch_shape.dart';
import 'ink_crop_screen.dart';

class InkChartAddScreen extends ConsumerStatefulWidget {
  const InkChartAddScreen({super.key, required this.bookId, this.entryToEdit});
  final String bookId;
  final InkChartModel? entryToEdit;

  @override
  ConsumerState<InkChartAddScreen> createState() => _InkChartAddScreenState();
}

class _InkChartAddScreenState extends ConsumerState<InkChartAddScreen> {
  File? _photo;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _inkNameCtrl;
  final _editorKey = GlobalKey<BlogBodyEditorState>();
  List<EditorBlock>? _initialEditorBlocks;
  bool _isSaving = false;
  bool _showEditorToolbar = false;

  List<String> _brandSuggestions = [];
  List<String> _nameSuggestions = [];

  bool get _isEditing => widget.entryToEdit != null;
  String? get _initialPhotoUrl => widget.entryToEdit?.photoUrl;

  @override
  void initState() {
    super.initState();
    final entry = widget.entryToEdit;
    final brandText = entry?.brand ?? '';
    final inkNameText = entry?.inkName ?? '';
    // text만 넘기고 끝내면 selection이 무효(offset: -1)로 남아서, 처음 탭해서
    // 포커스를 줄 때 텍스트가 순간적으로 사라지는 것처럼 보이는 버그가 있었음
    _brandCtrl = TextEditingController(text: brandText)
      ..selection = TextSelection.collapsed(offset: brandText.length);
    _inkNameCtrl = TextEditingController(text: inkNameText)
      ..selection = TextSelection.collapsed(offset: inkNameText.length);
    if (entry != null) {
      if (entry.contentBlocks != null && entry.contentBlocks!.isNotEmpty) {
        _initialEditorBlocks = editorBlocksFromMap(entry.contentBlocks!);
      } else if (entry.memo.isNotEmpty) {
        _initialEditorBlocks = [TextEditorBlock(initial: entry.memo)];
      }
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _inkNameCtrl.dispose();
    super.dispose();
  }

  // ── 뒤로가기 시 저장 확인 ──────────────────────────────────────────
  bool _hasContent() {
    if (_photo != null) return true;
    if (_brandCtrl.text.isNotEmpty || _inkNameCtrl.text.isNotEmpty) return true;
    final blocks = _editorKey.currentState?.getBlocks() ?? [];
    return blocks.any((b) {
      if (b is TextEditorBlock) return b.controller.text.isNotEmpty;
      if (b is ImageEditorBlock) return true;
      return false;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasContent()) return true;
    return confirmDiscardDialog(
      context,
      content: _isEditing
          ? '지금 나가면 수정한 내용이 저장되지 않습니다.'
          : '지금 나가면 작성한 내용이 모두 삭제됩니다.',
    );
  }

  // ── 사진 선택 ──────────────────────────────────────────────────
  void _openPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 88,
    );
    if (xFile == null || !mounted) return;
    final shape = ref.read(inkSwatchShapeProvider);
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) =>
            InkCropScreen(imageFile: File(xFile.path), shape: shape),
      ),
    );
    if (cropped != null) {
      setState(() => _photo = cropped);
    }
  }

  // ── 브랜드/잉크 이름 자동완성 (필드별로 각자 목록만 보여줌) ──────────
  Future<void> _searchBrand(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _brandSuggestions = []);
      return;
    }
    final results = await ref.read(archiveRepoProvider).searchInks(trimmed);
    if (!mounted) return;
    final lower = trimmed.toLowerCase();
    final brands = results
        .map((i) => i.brand)
        .where((b) => b.toLowerCase().contains(lower))
        .toSet()
        .take(8)
        .toList();
    setState(() => _brandSuggestions = brands);
  }

  Future<void> _searchName(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameSuggestions = []);
      return;
    }
    final results = await ref.read(archiveRepoProvider).searchInks(trimmed);
    if (!mounted) return;
    final lower = trimmed.toLowerCase();
    final names = results
        .map((i) => i.name)
        .where((n) => n.toLowerCase().contains(lower))
        .toSet()
        .take(8)
        .toList();
    setState(() => _nameSuggestions = names);
  }

  void _selectBrand(String brand) {
    _brandCtrl
      ..text = brand
      ..selection = TextSelection.collapsed(offset: brand.length);
    setState(() => _brandSuggestions = []);
  }

  void _selectName(String name) {
    _inkNameCtrl
      ..text = name
      ..selection = TextSelection.collapsed(offset: name.length);
    setState(() => _nameSuggestions = []);
    FocusScope.of(context).unfocus();
  }

  // ── 저장 ────────────────────────────────────────────────────────
  Future<void> _save() async {
    final brand = _brandCtrl.text.trim();
    final inkName = _inkNameCtrl.text.trim();

    if (_photo == null && _initialPhotoUrl == null) {
      _showSnack('발색 사진을 추가해주세요');
      return;
    }
    if (brand.isEmpty || inkName.isEmpty) {
      _showSnack('브랜드명과 잉크 이름을 입력해주세요');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) {
        setState(() => _isSaving = false);
        return;
      }

      // 1. 발색 사진 업로드 (새로 고른 사진이 있을 때만, 아니면 기존 사진 유지)
      final oldPhotoUrl = _initialPhotoUrl;
      final photoUrl = _photo != null
          ? await ref
                .read(storageServiceProvider)
                .uploadInkChartPhoto(_photo!, uid)
          : oldPhotoUrl!;

      // 2. 메모 블록(텍스트 + 추가 사진) 빌드
      final editorState = _editorKey.currentState;
      var memoBlocks = <Map<String, dynamic>>[];
      if (editorState != null) {
        memoBlocks = await editorState.buildContentBlocks(
          uploadImage: (file) => ref
              .read(storageServiceProvider)
              .uploadImage(file: file, folder: 'inkChart/$uid'),
        );
      }
      final memoText = memoBlocks
          .where((b) => b['type'] == 'text')
          .map((b) => b['content'] as String)
          .join('\n');

      final entry = InkChartModel(
        id: widget.entryToEdit?.id ?? const Uuid().v4(),
        photoUrl: photoUrl,
        brand: brand,
        inkName: inkName,
        memo: memoText,
        contentBlocks: memoBlocks.isNotEmpty ? memoBlocks : null,
        createdAt: widget.entryToEdit?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await ref
            .read(inkBookRepoProvider)
            .updateEntry(uid, widget.bookId, entry);
        // 사진을 새로 바꿨으면 예전 스토리지 파일은 정리
        if (_photo != null && oldPhotoUrl != null && oldPhotoUrl != photoUrl) {
          try {
            await ref.read(storageServiceProvider).deleteByUrl(oldPhotoUrl);
          } catch (_) {}
        }
        if (mounted) {
          setState(() => _isSaving = false);
          // showCenterToast는 자체적으로 다이얼로그 라우트를 push함 — pop()을
          // 바로 이어 부르면 이 화면이 아니라 방금 띄운 토스트 라우트가 닫혀버려서
          // 반드시 await로 토스트가 완전히 끝난 뒤에 pop 해야 함
          await showCenterToast(
            context,
            message: '수정했어요',
            icon: Icons.check_circle,
          );
          if (mounted) {
            // 이 화면은 go_router 라우트가 아니라 Navigator.push로 연 화면이라
            // context.pop()(go_router용)이 아니라 일반 Navigator pop을 써야 함
            Navigator.of(context).pop();
          }
        }
        return;
      }

      await ref.read(inkBookRepoProvider).addEntry(uid, widget.bookId, entry);

      if (mounted) {
        final shape = ref.read(inkSwatchShapeProvider);
        await showAddSuccessOverlay(
          context,
          visual: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkShapeClip(
              shape: shape,
              child: Image.file(_photo!, fit: BoxFit.cover),
            ),
          ),
          title: brand,
          subtitle: inkName,
          caption: '차트에 기록됐어요',
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('저장 실패: $e');
    }
  }

  void _showSnack(String msg) {
    showCenterToast(context, message: msg);
  }

  // ── UI ──────────────────────────────────────────────────────────
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: Text(_isEditing ? '잉크 스와치 수정' : '잉크 스와치 추가'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final leave = await _confirmDiscard();
              if (leave && mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사진 선택 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PhotoPicker(
                    photo: _photo,
                    photoUrl: _initialPhotoUrl,
                    shape: ref.watch(inkSwatchShapeProvider),
                    onTap: _openPhotoPicker,
                  ),
                ),
                const SizedBox(height: 24),

                // 섹션 레이블
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('브랜드'),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _brandCtrl,
                        hint: '예) Pilot, Diamine, Sailor',
                        textCapitalization: TextCapitalization.words,
                        onChanged: _searchBrand,
                      ),
                      if (_brandSuggestions.isNotEmpty)
                        _SuggestionList(
                          items: _brandSuggestions,
                          onTap: _selectBrand,
                        ),
                      const SizedBox(height: 16),
                      const _Label('잉크 이름'),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _inkNameCtrl,
                        hint: '예) Iroshizuku Tsuyugusa',
                        textCapitalization: TextCapitalization.words,
                        onChanged: _searchName,
                      ),
                      if (_nameSuggestions.isNotEmpty)
                        _SuggestionList(
                          items: _nameSuggestions,
                          onTap: _selectName,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _Label('메모 (선택)'),
                ),
                const SizedBox(height: 8),
                // 리뷰 본문 에디터와 동일한 컴포넌트 — 텍스트 중간에 사진 추가 가능,
                // 자체적으로 좌우 16px 여백을 가지므로 바깥에 별도 padding 없음
                BlogBodyEditor(
                  key: _editorKey,
                  hintText: '발색 느낌, 특성, 사용한 종이 등을 자유롭게 기록하세요',
                  initialBlocks: _initialEditorBlocks,
                  onFocusChanged: (hasFocus) =>
                      setState(() => _showEditorToolbar = hasFocus),
                ),
                const SizedBox(height: 12),

                // 안내 텍스트
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '직접 발색한 종이를 밝은 곳에서 사진 찍으면\n더 정확한 색감을 기록할 수 있어요',
                            style: AppTextStyles.bodySmall.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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

// ── 사진 선택 위젯 ────────────────────────────────────────────────────
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.photoUrl,
    required this.shape,
    required this.onTap,
  });
  final File? photo;
  final String? photoUrl;
  final InkSwatchShape shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null || photoUrl != null;
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: hasPhoto ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: hasPhoto
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    // 모양대로 클리핑된 이미지 (정방형 crop이므로 1:1 유지)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: InkShapeClip(
                          shape: shape,
                          child: photo != null
                              ? Image.file(photo!, fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  imageUrl: photoUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    // 사진 변경 버튼
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '사진 변경',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 44,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '발색 사진 추가',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '카메라 또는 갤러리에서 선택',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ── 공용 위젯 ─────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

// 브랜드/잉크 이름 자동완성 목록 — 브랜드 필드는 브랜드 이름만,
// 잉크 이름 필드는 잉크 이름만 각자 따로 보여준다 (서로 섞이지 않음)
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.items, required this.onTap});
  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (name) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onTap: () => onTap(name),
              ),
            )
            .toList(),
      ),
    );
  }
}
