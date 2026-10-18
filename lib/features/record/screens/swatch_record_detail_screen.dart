import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../mypage/providers/ink_shape_provider.dart';
import '../../mypage/widgets/ink_memo_content.dart';
import '../widgets/record_views.dart';
import 'swatch_record_screen.dart';

/// 스와치 기록 상세 — 잉크·펜·닙·종이·날짜·메모. 수정·삭제는 마이페이지 공책과 같은 문서를 다룬다.
class SwatchRecordDetailScreen extends ConsumerWidget {
  const SwatchRecordDetailScreen({
    super.key,
    required this.bookId,
    required this.entryId,
  });

  final String bookId;
  final String entryId;

  Future<void> _edit(BuildContext context, InkChartModel entry) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SwatchRecordScreen(editBookId: bookId, editEntry: entry),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String uid, InkChartModel entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('"${entry.displayName}" 기록을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(inkBookRepoProvider).deleteEntry(uid, bookId, entry.id);
    await ref.read(storageServiceProvider).deleteByUrl(entry.photoUrl);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const Scaffold();
    final chartAsync = ref.watch(inkChartInBookProvider((uid, bookId)));
    final books = ref.watch(inkBookListProvider(uid)).valueOrNull ?? const [];
    final bookName = books.where((b) => b.id == bookId).firstOrNull?.name;
    final entry = chartAsync.valueOrNull?.where((e) => e.id == entryId).firstOrNull;
    final shape = ref.watch(inkSwatchShapeProvider);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        actions: entry == null
            ? null
            : [
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, entry),
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref, uid, entry),
                ),
              ],
      ),
      body: switch (chartAsync) {
        _ when entry != null => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl,
            ),
            children: [
              Center(
                child: SizedBox(
                  width: 240,
                  child: SwatchThumbnail(entry: entry, shape: shape),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(entry.inkName, style: AppTextStyles.headlineSmall),
              if (entry.brand.isNotEmpty) Text(entry.brand, style: AppTextStyles.bodyMedium),
              if (entry.inkId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => context.push('/archive/ink/${entry.inkId}'),
                    icon: const Icon(Icons.book_outlined, size: 18),
                    label: const Text('아카이브에서 보기'),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              _InfoRow(label: '펜', value: entry.penName),
              _InfoRow(label: '닙', value: entry.nibSize),
              _InfoRow(label: '종이', value: entry.paperName),
              _InfoRow(label: '날짜', value: _formatDate(entry.recordDate)),
              _InfoRow(label: '공책', value: bookName),
              if (entry.memo.isNotEmpty || (entry.contentBlocks?.isNotEmpty ?? false)) ...[
                const Divider(height: AppSpacing.xxxl),
                InkMemoContent(entry: entry),
              ],
            ],
          ),
        AsyncError() => const Center(child: Text('기록을 불러오지 못했어요')),
        AsyncData() => const Center(child: Text('삭제된 기록이에요')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _formatDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(label, style: AppTextStyles.labelMedium)),
          Expanded(child: Text(v, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
