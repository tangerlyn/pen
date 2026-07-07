import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/providers.dart';
import 'center_toast.dart';

const _reportReasons = [
  '스팸/광고',
  '욕설/혐오 발언',
  '음란물',
  '개인정보 침해',
  '사기/거짓 정보',
  '기타',
];

Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  final currentUid = ref.read(currentUidProvider);
  if (currentUid == null) {
    showCenterToast(context, message: '로그인 후 이용 가능합니다.');
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      reporterId: currentUid,
    ),
  );
}

Future<void> showBlockDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetUid,
  required String targetNickname,
}) async {
  final currentUid = ref.read(currentUidProvider);
  if (currentUid == null) {
    showCenterToast(context, message: '로그인 후 이용 가능합니다.');
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('사용자 차단'),
      content: Text('$targetNickname 님을 차단하시겠습니까?\n차단하면 해당 사용자의 콘텐츠가 표시되지 않습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('차단', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(userRepoProvider).block(currentUid, targetUid);
    if (context.mounted) {
      showCenterToast(context, message: '차단되었습니다.', icon: Icons.check_circle);
    }
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.reporterId,
  });
  final String targetType;
  final String targetId;
  final String reporterId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _selectedReason;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(userRepoProvider).report(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reporterId: widget.reporterId,
            reason: _selectedReason!,
          );
      if (mounted) {
        Navigator.pop(context);
        showCenterToast(context, message: '신고가 접수되었습니다.', icon: Icons.check_circle);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showCenterToast(context,
            message: '신고 실패: $e', icon: Icons.error_outline, iconColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('신고 사유 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ..._reportReasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: _selectedReason,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _selectedReason = v),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('신고하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
