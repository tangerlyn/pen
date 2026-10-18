import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../shared/widgets/confirm_discard_dialog.dart';
import '../../../shared/widgets/editor/blog_body_editor.dart';
import '../../mypage/providers/ink_shape_provider.dart';
import '../../mypage/screens/ink_crop_screen.dart';
import '../../mypage/widgets/ink_add_success_overlay.dart';
import '../../mypage/widgets/ink_swatch_shape.dart';
import '../analytics/swatch_record_tracker.dart';
import '../controllers/swatch_record_controller.dart';
import '../providers/ink_catalog_provider.dart';
import '../widgets/ink_match_sheet.dart';
import '../widgets/swatch_record_fields.dart';

/// 스와치 기록 — 필수는 사진과 잉크 이름, 나머지(펜·닙·종이·날짜·메모)는 전부 선택.
/// 새 기록은 `/record/new`로, 수정은 기록 상세에서 Navigator.push로 연다.
class SwatchRecordScreen extends ConsumerStatefulWidget {
  const SwatchRecordScreen({
    super.key,
    this.entryQuery,
    this.presetInkId,
    this.editBookId,
    this.editEntry,
  });

  /// 라우트 쿼리 `entry` (분석용 진입 경로)
  final String? entryQuery;
  final String? presetInkId;
  final String? editBookId;
  final InkChartModel? editEntry;

  @override
  ConsumerState<SwatchRecordScreen> createState() => _SwatchRecordScreenState();
}

class _SwatchRecordScreenState extends ConsumerState<SwatchRecordScreen> {
  late final SwatchRecordArgs _args;
  late final TextEditingController _penCtrl;
  late final TextEditingController _nibCtrl;
  late final TextEditingController _paperCtrl;
  final _editorKey = GlobalKey<BlogBodyEditorState>();
  List<EditorBlock>? _initialEditorBlocks;
  bool _showOptional = false;
  bool _showEditorToolbar = false;

  AutoDisposeStateNotifierProvider<SwatchRecordController, SwatchRecordState>
      get _provider => swatchRecordControllerProvider(_args);
  SwatchRecordController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    final edit = widget.editEntry;
    _args = SwatchRecordArgs(
      entryPoint: edit != null
          ? SwatchEntryPoint.recordDetail
          : SwatchEntryPoint.fromQuery(widget.entryQuery),
      presetInkId: widget.presetInkId,
      editBookId: widget.editBookId,
      editEntry: edit,
    );
    _penCtrl = TextEditingController(text: edit?.penName ?? '');
    _nibCtrl = TextEditingController(text: edit?.nibSize ?? '');
    _paperCtrl = TextEditingController(text: edit?.paperName ?? '');
    if (edit != null) {
      if (edit.contentBlocks != null && edit.contentBlocks!.isNotEmpty) {
        _initialEditorBlocks = editorBlocksFromMap(edit.contentBlocks!);
      } else if (edit.memo.isNotEmpty) {
        _initialEditorBlocks = [TextEditorBlock(initial: edit.memo)];
      }
      _showOptional = SwatchRecordState.fromEntry(edit).hasOptionalInput ||
          _initialEditorBlocks != null;
    }
    // 컨트롤러를 바로 만들어 swatch_record_start가 진입 시점에 남게 한다
    ref.read(_provider.notifier);
    if (widget.presetInkId != null) _applyPresetInk(widget.presetInkId!);
  }

  @override
  void dispose() {
    _penCtrl.dispose();
    _nibCtrl.dispose();
    _paperCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPresetInk(String inkId) async {
    try {
      final catalog = await ref.read(inkCatalogProvider.future);
      final ink = catalog.where((i) => i.id == inkId).firstOrNull ??
          await ref.read(archiveRepoProvider).getInk(inkId);
      if (ink != null && mounted) _controller.applyPresetInk(ink);
    } catch (_) {
      // 미리 채우기는 편의 기능 — 실패하면 사용자가 직접 고르면 된다
    }
  }

  // ── 나가기 ───────────────────────────────────────────────────────
  bool _hasContent() {
    final s = ref.read(_provider);
    if (s.photo != null || s.hasOptionalInput) return true;
    if (!_args.isEdit && s.hasInk) return true;
    final blocks = _editorKey.currentState?.getBlocks() ?? [];
    return blocks.any((b) =>
        (b is TextEditorBlock && b.controller.text.isNotEmpty) || b is ImageEditorBlock);
  }

  Future<void> _leave() async {
    final hadContent = _hasContent();
    if (hadContent) {
      final leave = await confirmDiscardDialog(
        context,
        content: _args.isEdit
            ? '지금 나가면 수정한 내용이 저장되지 않습니다.'
            : '지금 나가면 기록한 내용이 모두 삭제됩니다.',
      );
      if (!leave || !mounted) return;
    }
    _controller.exit(hadContent: hadContent);
    Navigator.of(context).pop();
  }

  // ── 사진 ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final xFile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 88,
    );
    if (xFile == null || !mounted) return;
    // 잉크 차트와 같은 크롭 화면·모양 설정을 그대로 쓴다
    final shape = ref.read(inkSwatchShapeProvider);
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => InkCropScreen(imageFile: File(xFile.path), shape: shape),
      ),
    );
    if (cropped == null || !mounted) return;
    _controller.setPhoto(
      cropped,
      source: source == ImageSource.camera
          ? SwatchPhotoSource.camera
          : SwatchPhotoSource.gallery,
      cropShape: shape.name,
    );
  }

  // ── 잉크 ─────────────────────────────────────────────────────────
  Future<void> _matchInk() async {
    FocusScope.of(context).unfocus();
    final selection = await showInkMatchSheet(context);
    if (selection == null || !mounted) return;
    if (selection.matchType == SwatchMatchType.request) {
      try {
        await _controller.requestNewInk(
          brand: selection.ink.brand,
          name: selection.ink.name,
          queryLength: selection.queryLength,
          filterCount: selection.filterCount,
        );
        if (mounted) {
          showCenterToast(context, message: '아카이브 추가를 요청했어요', icon: Icons.check_circle);
        }
      } catch (_) {
        // 요청이 실패해도 기록은 이어갈 수 있게 이름만으로 연결
        _controller.selectInk(
          selection.ink,
          matchType: SwatchMatchType.freeText,
          queryLength: selection.queryLength,
          filterCount: selection.filterCount,
        );
        if (mounted) {
          showCenterToast(context, message: '요청을 보내지 못했어요. 이름은 그대로 기록돼요');
        }
      }
      return;
    }
    _controller.selectInk(
      selection.ink,
      matchType: selection.matchType,
      queryLength: selection.queryLength,
      filterCount: selection.filterCount,
    );
  }

  // ── 저장 ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final photo = ref.read(_provider).photo;
    final shape = ref.read(inkSwatchShapeProvider);
    final storage = ref.read(storageServiceProvider);
    try {
      final result = await _controller.save(
        buildMemoBlocks: (uid) async {
          final editor = _editorKey.currentState;
          if (editor == null) return [];
          return editor.buildContentBlocks(
            uploadImage: (file) => storage.uploadImage(file: file, folder: 'inkChart/$uid'),
          );
        },
      );
      if (result == null || !mounted) return;

      if (_args.isEdit) {
        // showCenterToast는 다이얼로그 라우트를 push하므로 끝난 뒤에 pop 해야 이 화면이 닫힘
        await showCenterToast(context, message: '수정했어요', icon: Icons.check_circle);
        if (mounted) Navigator.of(context).pop(result.entry);
        return;
      }

      final entry = result.entry;
      await showAddSuccessOverlay(
        context,
        visual: InkShapeClip(
          shape: shape,
          child: photo != null
              ? Image.file(photo, fit: BoxFit.cover)
              : const ColoredBox(color: AppColors.chipBackground),
        ),
        title: entry.brand.isEmpty ? entry.inkName : entry.brand,
        subtitle: entry.brand.isEmpty ? '' : entry.inkName,
        caption: result.createdBook
            ? "'$kDefaultRecordBookName' 공책에 기록했어요"
            : '기록했어요',
      );
      if (mounted) Navigator.of(context).pop(result.entry);
    } catch (_) {
      if (mounted) {
        showCenterToast(context, message: '저장하지 못했어요. 연결을 확인하고 다시 시도해주세요');
      }
    }
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final shape = ref.watch(inkSwatchShapeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: Text(_args.isEdit ? '기록 수정' : '스와치 기록'),
          leading: IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.close),
            onPressed: _leave,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton(
                key: const Key('swatch_save_button'),
                onPressed: state.canSave ? _save : null,
                child: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxxl),
            children: [
              Padding(
                padding: AppSpacing.pagePadding,
                child: SwatchPhotoField(
                  photo: state.photo,
                  photoUrl: state.existingPhotoUrl,
                  shape: shape,
                  onTap: _pickPhoto,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SwatchSectionLabel('잉크', required: true),
                    const SizedBox(height: AppSpacing.sm),
                    SwatchInkField(ink: state.ink, onTap: _matchInk),
                    if (!state.canSave && !state.isSaving) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        '사진과 잉크만 있으면 저장할 수 있어요',
                        style: AppTextStyles.labelMedium,
                      ),
                    ],
                    if (!_args.isEdit) _BookSelector(selectedId: state.bookId, onSelect: _controller.setBook),
                    const SizedBox(height: AppSpacing.sm),
                    _OptionalToggle(
                      expanded: _showOptional,
                      onTap: () => setState(() => _showOptional = !_showOptional),
                    ),
                  ],
                ),
              ),
              // 접어도 입력한 메모·사진이 사라지지 않게 위젯은 유지하고 숨기기만 한다
              Visibility(
                visible: _showOptional,
                maintainState: true,
                child: Column(
                  children: [
                    Padding(
                      padding: AppSpacing.pagePadding,
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.sm),
                          SwatchTextField(
                            controller: _penCtrl,
                            label: '펜',
                            hint: '예) Pilot Custom 74',
                            onChanged: _controller.setPenName,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SwatchTextField(
                            controller: _nibCtrl,
                            label: '닙',
                            hint: '예) F, M, 스텁 1.1',
                            maxLength: 40,
                            onChanged: _controller.setNibSize,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SwatchTextField(
                            controller: _paperCtrl,
                            label: '종이',
                            hint: '예) 토모에리버 52g',
                            onChanged: _controller.setPaperName,
                          ),
                          SwatchDateTile(date: state.recordedAt, onChanged: _controller.setRecordedAt),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SwatchSectionLabel('메모'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 자체적으로 좌우 16px 여백을 가지므로 바깥 padding 없음
                    BlogBodyEditor(
                      key: _editorKey,
                      hintText: '발색 느낌, 쉰·셰이딩, 건조 시간 등을 자유롭게 기록하세요',
                      initialBlocks: _initialEditorBlocks,
                      onFocusChanged: (hasFocus) => setState(() => _showEditorToolbar = hasFocus),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _showEditorToolbar
            ? Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: BlogEditorToolbar(editorKey: _editorKey),
              )
            : null,
      ),
    );
  }
}

class _BookSelector extends ConsumerWidget {
  const _BookSelector({required this.selectedId, required this.onSelect});
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();
    final books = ref.watch(inkBookListProvider(uid)).valueOrNull;
    if (books == null) return const SizedBox.shrink();
    final lastUsed = ref.watch(lastRecordBookIdProvider).valueOrNull;
    return SwatchBookTile(
      books: books,
      selectedId: selectedId ?? resolveDefaultBookId(books, lastUsed),
      onSelect: onSelect,
    );
  }
}

class _OptionalToggle extends StatelessWidget {
  const _OptionalToggle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: const Text('펜·닙·종이·날짜·메모 더 기록하기', style: AppTextStyles.titleSmall),
      subtitle: const Text('모두 선택 항목이에요', style: AppTextStyles.labelMedium),
      trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
    );
  }
}
