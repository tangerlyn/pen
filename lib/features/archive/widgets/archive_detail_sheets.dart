part of '../screens/archive_detail_screen.dart';

const _kEditInkTypeLabels = ['일반', '펄', '테'];
const _kEditInkTypeValues = ['normal', 'shimmer', 'sheen'];

class _EditInkSheet extends ConsumerStatefulWidget {
  const _EditInkSheet({required this.ink});
  final InkModel ink;

  @override
  ConsumerState<_EditInkSheet> createState() => _EditInkSheetState();
}

class _EditInkSheetState extends ConsumerState<_EditInkSheet> {
  late final TextEditingController _brandCtrl = TextEditingController(
    text: widget.ink.brand,
  );
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.ink.name,
  );
  late String _inkType = widget.ink.inkType;
  late Color _color = widget.ink.inkColor;
  bool _isSaving = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _brandCtrl.text.trim().isNotEmpty && _nameCtrl.text.trim().isNotEmpty;

  static String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
              '${c.green.toRadixString(16).padLeft(2, '0')}'
              '${c.blue.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  Future<void> _submit() async {
    if (!_isValid || _isSaving) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(archiveRepoProvider)
          .updateInk(
            inkId: widget.ink.id,
            brand: _brandCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            inkType: _inkType,
            hexColor: _colorToHex(_color),
          );
      ref.invalidate(archiveDetailProvider);
      ref.read(archiveProvider.notifier).refresh();
      if (mounted) {
        Navigator.pop(context);
        showCenterToast(
          context,
          message: '잉크 정보를 수정했어요.',
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        showCenterToast(
          context,
          message: '수정 실패: $e',
          icon: Icons.error_outline,
          iconColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 16, bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '잉크 정보 수정',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editLabel('브랜드명'),
                      const SizedBox(height: 6),
                      _editTextField(_brandCtrl, '예: PILOT, Sailor, Diamine'),
                      const SizedBox(height: 14),
                      _editLabel('잉크 이름'),
                      const SizedBox(height: 6),
                      _editTextField(_nameCtrl, '예: Iroshizuku 쓰유쿠사'),
                      const SizedBox(height: 16),
                      _editLabel('잉크 타입'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_kEditInkTypeLabels.length, (
                          i,
                        ) {
                          final selected = _inkType == _kEditInkTypeValues[i];
                          return GestureDetector(
                            onTap: () => setState(
                              () => _inkType = _kEditInkTypeValues[i],
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.chipBackground,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                              ),
                              child: Text(
                                _kEditInkTypeLabels[i],
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      _editLabel('대표 색상'),
                      const SizedBox(height: 12),
                      InkColorPicker(
                        color: _color,
                        onChanged: (c) => setState(() => _color = c),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid && !_isSaving ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.chipBackground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '수정 완료',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editLabel(String text) => Text(
    text,
    style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
  );

  Widget _editTextField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 14),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: AppColors.chipBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// ── 신고 시트 ──────────────────────────────────────────────────────────────
class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.type,
    required this.productId,
    required this.targetName,
  });
  final String type;
  final String productId;
  final String targetName;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  static const _reasons = ['잘못된 정보', '중복 등록', '부적절한 내용', '기타'];
  String? _selectedReason;
  final _detailCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _isSubmitting) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(archiveRepoProvider);
      final alreadyReported = await repo.hasReportedProduct(
        targetType: widget.type,
        targetId: widget.productId,
        reporterId: uid,
      );
      if (alreadyReported) {
        if (mounted) {
          Navigator.pop(context);
          showCenterToast(
            context,
            message: '이미 신고한 제품이에요.',
            icon: Icons.info_outline,
          );
        }
        return;
      }
      await repo.reportProduct(
        targetType: widget.type,
        targetId: widget.productId,
        targetName: widget.targetName,
        reporterId: uid,
        reason: _selectedReason!,
        detail: _detailCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showCenterToast(
          context,
          message: '신고가 접수됐어요. 검토 후 처리될 예정이에요.',
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        showCenterToast(
          context,
          message: '신고 실패: $e',
          icon: Icons.error_outline,
          iconColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Text(
                '신고 사유',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '신고 유형 *',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reasons.map((r) {
                      final selected = r == _selectedReason;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedReason = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            r,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '상세 사유 (선택)',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '추가적인 사유가 있으면 입력해주세요',
                      hintStyle: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: AppColors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedReason != null && !_isSubmitting
                          ? _submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.chipBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '신고 제출',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
