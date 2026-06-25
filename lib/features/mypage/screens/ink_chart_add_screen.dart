import 'dart:io';
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
import '../providers/ink_shape_provider.dart';
import '../widgets/ink_add_success_overlay.dart';
import '../widgets/ink_swatch_shape.dart';
import 'ink_crop_screen.dart';

class InkChartAddScreen extends ConsumerStatefulWidget {
  const InkChartAddScreen({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<InkChartAddScreen> createState() => _InkChartAddScreenState();
}

class _InkChartAddScreenState extends ConsumerState<InkChartAddScreen> {
  static const _bg = Color(0xFFF5F0E6);

  File? _photo;
  final _brandCtrl = TextEditingController();
  final _inkNameCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _inkNameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // ── 사진 선택 ──────────────────────────────────────────────────
  void _openPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  // ── 저장 ────────────────────────────────────────────────────────
  Future<void> _save() async {
    final brand = _brandCtrl.text.trim();
    final inkName = _inkNameCtrl.text.trim();

    if (_photo == null) {
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
      if (uid == null) return;
      final id = const Uuid().v4();

      // 1. 사진 업로드
      final photoUrl = await ref
          .read(storageServiceProvider)
          .uploadInkChartPhoto(_photo!, uid);

      // 2. Firestore 저장
      final entry = InkChartModel(
        id: id,
        photoUrl: photoUrl,
        brand: brand,
        inkName: inkName,
        memo: _memoCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(inkBookRepoProvider).addEntry(uid, widget.bookId, entry);

      if (mounted) {
        await showInkAddSuccess(
          context,
          photo: _photo!,
          shape: ref.read(inkSwatchShapeProvider),
          brand: brand,
          inkName: inkName,
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('저장 실패: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        scrolledUnderElevation: 0,
        title: const Text('잉크 스와치 추가'),
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
                          fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진 선택 영역
              _PhotoPicker(
                photo: _photo,
                shape: ref.watch(inkSwatchShapeProvider),
                onTap: _openPhotoPicker,
              ),
              const SizedBox(height: 24),

              // 섹션 레이블
              const _Label('브랜드'),
              const SizedBox(height: 8),
              _Field(
                controller: _brandCtrl,
                hint: '예) Pilot, Diamine, Sailor',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              const _Label('잉크 이름'),
              const SizedBox(height: 8),
              _Field(
                controller: _inkNameCtrl,
                hint: '예) Iroshizuku Tsuyugusa',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              const _Label('메모 (선택)'),
              const SizedBox(height: 8),
              _Field(
                controller: _memoCtrl,
                hint: '발색 느낌, 특성, 사용한 종이 등을 자유롭게 기록하세요',
                maxLines: 5,
              ),
              const SizedBox(height: 12),

              // 안내 텍스트
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFFB8A98A)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '직접 발색한 종이를 밝은 곳에서 사진 찍으면\n더 정확한 색감을 기록할 수 있어요',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B7355),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 사진 선택 위젯 ────────────────────────────────────────────────────
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.shape,
    required this.onTap,
  });
  final File? photo;
  final InkSwatchShape shape;
  final VoidCallback onTap;

  static const _border = Color(0xFFD4C5A9);

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: photo != null ? _border : AppColors.divider,
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
          child: photo != null
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
                          child: Image.file(photo!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    // 사진 변경 버튼
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('사진 변경',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 44, color: Color(0xFFB8A98A)),
                      SizedBox(height: 10),
                      Text(
                        '발색 사진 추가',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B7355)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '카메라 또는 갤러리에서 선택',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
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
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: const Color(0xFFFFFDF7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C5A9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C5A9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
