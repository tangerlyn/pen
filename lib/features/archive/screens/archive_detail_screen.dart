import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/archive_detail_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/wishlist_providers.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
// import 'ink_compare_screen.dart'; // 색상 비교 — 구현 완료, 적용 보류

class ArchiveDetailScreen extends ConsumerWidget {
  const ArchiveDetailScreen({super.key, required this.type, required this.productId});
  final String type;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveDetailProvider((type: type, productId: productId)));
    final data = state.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: data == null
            ? null
            : Text(
                type == 'ink' ? (data as InkModel).name : data.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
        actions: data == null
            ? []
            : [
                _WishlistButton(
                  type: type,
                  productId: productId,
                  productName: type == 'ink' ? (data as InkModel).name : data.displayName,
                  brand: data.brand,
                  hexColor: type == 'ink' ? (data as InkModel).hexColor : '',
                ),
                _ReportButton(
                  type: type,
                  productId: productId,
                  targetName: data.displayName,
                ),
              ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('오류: $e')),
        data: (data) => data == null
            ? const Center(child: Text('제품을 찾을 수 없습니다.'))
            : _DetailBody(type: type, data: data, productId: productId),
      ),
    );
  }
}

// ── 본문 (SingleChildScrollView — Viewport 없음, 너비 항상 유한) ──────────────
class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.type, required this.data, required this.productId});
  final String type;
  final dynamic data;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync =
        ref.watch(productReviewsProvider((type: type, productId: productId)));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (type == 'ink') _InkHeroHeader(hexColor: data.hexColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(type: type, data: data),
                const SizedBox(height: 16),
                // 색상 비교 버튼 — 구현 완료, 적용 보류 (ink_compare_screen.dart)
                // if (type == 'ink') Row(children: [Expanded(리뷰작성), SizedBox(8), OutlinedButton(색상비교)])
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                        '/write/review?type=$type&productId=$productId'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('리뷰 작성'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '사용자 리뷰',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          reviewsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('오류: $e')),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      '아직 리뷰가 없습니다.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = (constraints.maxWidth - 1) / 2;
                  return Wrap(
                    spacing: 1,
                    runSpacing: 1,
                    children: list
                        .map(
                          (review) => SizedBox(
                            width: w,
                            height: w / 0.85,
                            child: ReviewFeedCard(
                              review: review,
                              onTap: () =>
                                  context.push('/review/${review.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 잉크 헤더 (AppBar 바로 아래 색상 배경) ──────────────────────────────────
class _InkHeroHeader extends StatelessWidget {
  const _InkHeroHeader({required this.hexColor});
  final String hexColor;

  @override
  Widget build(BuildContext context) {
    Color color;
    try {
      color = Color(int.parse('FF${hexColor.replaceAll('#', '')}', radix: 16));
    } catch (e) {
      color = Colors.grey.shade300;
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.62)!,
            Color.lerp(color, Colors.white, 0.40)!,
          ],
        ),
      ),
      child: Center(child: InkDropCircle(color: color, size: 80)),
    );
  }
}

// ── 정보 카드 ──────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.type, required this.data});
  final String type;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[];
    if (type == 'ink') {
      rows.addAll([
        MapEntry('브랜드', data.brand),
        MapEntry('타입', data.inkTypeLabel),
      ]);
    } else if (type == 'pen') {
      rows.addAll([
        MapEntry('브랜드', data.brand),
        MapEntry('라인업', data.lineup),
        MapEntry('닙 소재', data.nibMaterial),
        MapEntry('충전 방식', data.fillType),
        MapEntry('닙 사이즈', data.nibSizes.join(', ')),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.70),
          width: 1.2,
        ),
        boxShadow: AppShadows.cardMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ── 위시리스트 버튼 ────────────────────────────────────────────────────────
class _WishlistButton extends ConsumerWidget {
  const _WishlistButton({
    required this.type,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.hexColor,
  });
  final String type;
  final String productId;
  final String productName;
  final String brand;
  final String hexColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWishlisted =
        ref.watch(wishlistStatusProvider(productId)).valueOrNull ?? false;
    return IconButton(
      icon: Icon(
        isWishlisted ? Icons.favorite : Icons.favorite_border,
        color: isWishlisted ? Colors.redAccent : null,
      ),
      onPressed: () => ref.read(wishlistActionsProvider).toggle(
            type: type,
            productId: productId,
            productName: productName,
            brand: brand,
            hexColor: hexColor,
          ),
    );
  }
}

// ── 신고 버튼 ──────────────────────────────────────────────────────────────
class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.type,
    required this.productId,
    required this.targetName,
  });
  final String type;
  final String productId;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('신고하기',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(sheetCtx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!ctx.mounted) return;
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (innerCtx) => _ReportSheet(
                      type: type,
                      productId: productId,
                      targetName: targetName,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
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
      await ref.read(archiveRepoProvider).reportProduct(
            targetType: widget.type,
            targetId: widget.productId,
            targetName: widget.targetName,
            reporterId: uid,
            reason: _selectedReason!,
            detail: _detailCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수됐어요. 검토 후 처리될 예정이에요.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('신고 실패: $e')));
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
              child: Text('신고 사유',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신고 유형 *',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
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
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(r,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('상세 사유 (선택)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '추가적인 사유가 있으면 입력해주세요',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _selectedReason != null && !_isSubmitting ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.chipBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('신고 제출',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
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

