import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../../../data/models/inquiry_model.dart';

// ── provider ─────────────────────────────────────────────────────────────────

final _myInquiriesProvider = StreamProvider<List<InquiryModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(inquiryRepoProvider).watchMyInquiries(uid);
});

final _inquiryDetailProvider =
    StreamProvider.family<InquiryModel?, String>((ref, id) {
  return ref.read(inquiryRepoProvider).watchInquiry(id);
});

// ── 문의 목록 화면 ────────────────────────────────────────────────────────────

class InquiryListScreen extends ConsumerWidget {
  const InquiryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myInquiriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('문의하기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '새 문의 작성',
            onPressed: () => context.push('/mypage/settings/inquiries/write'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  const Text(
                    '문의 내역이 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('새 문의 작성'),
                    onPressed: () =>
                        context.push('/mypage/settings/inquiries/write'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _InquiryTile(inquiry: list[i]),
          );
        },
      ),
    );
  }
}

class _InquiryTile extends StatelessWidget {
  const _InquiryTile({required this.inquiry});
  final InquiryModel inquiry;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('yyyy.MM.dd').format(inquiry.createdAt.toLocal());
    return ListTile(
      onTap: () =>
          context.push('/mypage/settings/inquiries/${inquiry.id}'),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              inquiry.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(isAnswered: inquiry.isAnswered),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                inquiry.content,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(dateStr,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textTertiary, size: 18),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isAnswered});
  final bool isAnswered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAnswered
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAnswered ? '답변 완료' : '확인 중',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isAnswered
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
        ),
      ),
    );
  }
}

// ── 문의 상세 화면 ────────────────────────────────────────────────────────────

class InquiryDetailScreen extends ConsumerWidget {
  const InquiryDetailScreen({super.key, required this.inquiryId});
  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_inquiryDetailProvider(inquiryId));

    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (inquiry) {
          if (inquiry == null) {
            return const Center(child: Text('문의를 찾을 수 없습니다.'));
          }
          return _InquiryDetailBody(inquiry: inquiry);
        },
      ),
    );
  }
}

class _InquiryDetailBody extends StatelessWidget {
  const _InquiryDetailBody({required this.inquiry});
  final InquiryModel inquiry;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm')
        .format(inquiry.createdAt.toLocal());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 제목 + 상태
        Row(
          children: [
            Expanded(
              child: Text(
                inquiry.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            _StatusBadge(isAnswered: inquiry.isAnswered),
          ],
        ),
        const SizedBox(height: 6),
        Text(dateStr,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary)),
        const Divider(height: 28),
        // 문의 내용
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            inquiry.content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
        // 답변
        if (inquiry.isAnswered && inquiry.answer != null) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.support_agent,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                '관리자 답변',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (inquiry.answeredAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy.MM.dd')
                      .format(inquiry.answeredAt!.toLocal()),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              inquiry.answer!,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ] else ...[
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: const [
                Icon(Icons.hourglass_top_outlined,
                    size: 32, color: AppColors.textTertiary),
                SizedBox(height: 8),
                Text(
                  '답변을 준비 중입니다.\n빠른 시일 내 답변 드리겠습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── 새 문의 작성 화면 ─────────────────────────────────────────────────────────

class InquiryWriteScreen extends ConsumerStatefulWidget {
  const InquiryWriteScreen({super.key});

  @override
  ConsumerState<InquiryWriteScreen> createState() => _InquiryWriteScreenState();
}

class _InquiryWriteScreenState extends ConsumerState<InquiryWriteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _contentCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(inquiryRepoProvider).createInquiry(
            uid: uid,
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의가 접수됐습니다.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 문의 작성'),
        actions: [
          TextButton(
            onPressed: _isValid && !_isSubmitting ? _submit : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('제출'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('제목',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '문의 제목을 입력해주세요',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: AppColors.chipBackground,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            const Text('문의 내용',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: 10,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '문의하실 내용을 자세히 적어주세요.',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: AppColors.chipBackground,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
