import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/providers/owned_ink_providers.dart';
import '../../../shared/widgets/center_toast.dart';

/// 잉크 상세에서 바로 기록으로 들어가는 버튼 두 개 — 내 컬렉션 토글, 스와치 기록
class InkRecordActions extends ConsumerStatefulWidget {
  const InkRecordActions({super.key, required this.ink});
  final InkModel ink;

  @override
  ConsumerState<InkRecordActions> createState() => _InkRecordActionsState();
}

class _InkRecordActionsState extends ConsumerState<InkRecordActions> {
  bool _busy = false;

  Future<void> _toggleOwned(bool isOwned) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final added = await ref
          .read(ownedInkActionsProvider)
          .toggle(widget.ink, isOwned: isOwned);
      if (added != null && mounted) {
        showCenterToast(
          context,
          message: added ? '내 컬렉션에 담았어요' : '내 컬렉션에서 뺐어요',
          icon: added ? Icons.check_circle : null,
        );
      }
    } catch (_) {
      if (mounted) showCenterToast(context, message: '잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwned = ref.watch(ownedInkStatusProvider(widget.ink.id)).valueOrNull ?? false;
    const buttonShape = StadiumBorder();
    const buttonSize = Size.fromHeight(52);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _toggleOwned(isOwned),
            style: OutlinedButton.styleFrom(
              minimumSize: buttonSize,
              shape: buttonShape,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            icon: Icon(isOwned ? Icons.check : Icons.add),
            label: Text(isOwned ? '내 컬렉션에 있음' : '내 컬렉션에 추가'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(
              '/record/new?inkId=${Uri.encodeQueryComponent(widget.ink.id)}&entry=ink_detail',
            ),
            style: FilledButton.styleFrom(
              minimumSize: buttonSize,
              shape: buttonShape,
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('스와치 기록하기'),
          ),
        ),
      ],
    );
  }
}
