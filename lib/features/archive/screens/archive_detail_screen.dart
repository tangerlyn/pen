import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/archive_detail_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../features/archive/providers/archive_provider.dart';
import '../../../shared/widgets/review/review_feed_card.dart';

class ArchiveDetailScreen extends ConsumerWidget {
  const ArchiveDetailScreen({super.key, required this.type, required this.productId});
  final String type; // ink / pen / paper
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveDetailProvider((type: type, productId: productId)));

    return Scaffold(
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (data) => data == null
            ? const Center(child: Text('제품을 찾을 수 없습니다.'))
            : _DetailContent(type: type, data: data, productId: productId),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.type, required this.data, required this.productId});
  final String type;
  final dynamic data;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: type == 'ink' ? 200 : 120,
          pinned: true,
          actions: [
            _ReportButton(
              type: type,
              productId: productId,
              targetName: data.displayName,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: type == 'ink'
                ? _InkHeroBackground(hexColor: data.hexColor)
                : Container(color: AppColors.chipBackground),
            title: Text(type == 'ink' ? data.name : data.displayName),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfo(data),
                const SizedBox(height: 16),
                // 액션 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/write/review?type=$type&productId=$productId'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('리뷰 작성'),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 리뷰 갤러리
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('사용자 리뷰', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
        _ReviewGallery(type: type, productId: productId),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildInfo(dynamic data) {
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                Expanded(child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ── 잉크 Hero 배경 ────────────────────────────────────────────────────
class _InkHeroBackground extends StatelessWidget {
  const _InkHeroBackground({required this.hexColor});
  final String hexColor;

  @override
  Widget build(BuildContext context) {
    Color color;
    try {
      color = Color(int.parse('FF${hexColor.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      color = Colors.grey.shade300;
    }
    final lighter = Color.lerp(color, Colors.white, 0.35)!;
    final darker  = Color.lerp(color, Colors.black, 0.25)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(2, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.35),
                      radius: 0.85,
                      colors: [lighter, color, darker],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 13,
                  top:  9,
                  child: Container(
                    width: 27,
                    height: 19,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end:   Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.88),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
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

// ── 신고 버튼 ─────────────────────────────────────────────────────────────
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
      builder: (_) => SafeArea(
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
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => _ReportSheet(
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

// ── 신고 시트 ─────────────────────────────────────────────────────────────
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
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

// ── 리뷰 갤러리 ────────────────────────────────────────────────────────
class _ReviewGallery extends ConsumerWidget {
  const _ReviewGallery({required this.type, required this.productId});
  final String type;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(productReviewsProvider((type: type, productId: productId)));
    return reviews.when(
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('오류: $e'))),
      data: (list) => list.isEmpty
          ? const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('아직 리뷰가 없습니다.')),
              ),
            )
          : SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final review = list[i];
                  return ReviewFeedCard(
                    review: review,
                    onTap: () => context.push('/review/${review.id}'),
                  );
                },
                childCount: list.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 0.85,
              ),
            ),
    );
  }
}
