import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/common/empty_state.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../providers/user_activity_provider.dart';
import '../widgets/ink_detail_carousel.dart';
import '../widgets/ink_memo_content.dart';
import '../widgets/ink_swatch_shape.dart';
import '../widgets/notebook_page.dart';

/// 다른 유저의 공개/팔로워공개 잉크 차트를 읽기 전용으로 보여주는 화면.
/// 소유자가 설정한 공책 모양(pageStyle/viewMode)과 스와치 모양을 그대로 반영한다.
class InkBookReadonlyScreen extends ConsumerStatefulWidget {
  const InkBookReadonlyScreen({
    super.key,
    required this.uid,
    required this.bookId,
    this.bookName,
  });

  final String uid;
  final String bookId;
  final String? bookName;

  @override
  ConsumerState<InkBookReadonlyScreen> createState() =>
      _InkBookReadonlyScreenState();
}

class _InkBookReadonlyScreenState extends ConsumerState<InkBookReadonlyScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(
      inkChartReadonlyProvider((widget.uid, widget.bookId)),
    );
    final book = ref
        .watch(singleInkBookProvider((widget.uid, widget.bookId)))
        .valueOrNull;
    final owner = ref.watch(profileUserProvider(widget.uid)).valueOrNull;

    final pageStyle = notebookPageStyleFromString(book?.pageStyle ?? 'lines');
    final isScroll = (book?.viewMode ?? 'pageView') == 'scroll';
    final shape = InkSwatchShape.values.firstWhere(
      (s) => s.name == (owner?.inkSwatchShape ?? 'circle'),
      orElse: () => InkSwatchShape.circle,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(book?.name ?? widget.bookName ?? '잉크 차트'),
      ),
      body: chartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyStateWidget(
          icon: Icons.cloud_off_outlined,
          message: '오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.water_drop_outlined,
              message: '아직 등록된 잉크가 없어요',
            );
          }

          final pageCount = (entries.length / NotebookPage.itemsPerPage).ceil();

          return Builder(
            builder: (ctx) {
              final mq = MediaQuery.of(ctx);
              const pageIndicatorH = 40.0;
              final pageViewHeight =
                  mq.size.height -
                  mq.padding.top -
                  mq.padding.bottom -
                  kToolbarHeight -
                  pageIndicatorH -
                  16.0;

              return Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: const Alignment(0, -0.4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: pageViewHeight - 60,
                            child: PageView.builder(
                              scrollDirection: isScroll
                                  ? Axis.vertical
                                  : Axis.horizontal,
                              itemCount: pageCount,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p),
                              itemBuilder: (_, pageIdx) {
                                final start =
                                    pageIdx * NotebookPage.itemsPerPage;
                                final end = math.min(
                                  start + NotebookPage.itemsPerPage,
                                  entries.length,
                                );
                                final pageEntries = entries.sublist(start, end);
                                return NotebookPage(
                                  pageEntries: pageEntries,
                                  pageStyle: pageStyle,
                                  itemBuilder: (c, entry, i) =>
                                      _ReadonlySwatchCard(
                                        entry: entry,
                                        shape: shape,
                                        allEntries: entries,
                                        absoluteIndex: start + i,
                                      ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (pageCount > 1)
                            Text(
                              '${_currentPage + 1} / $pageCount',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReadonlySwatchCard extends StatelessWidget {
  const _ReadonlySwatchCard({
    required this.entry,
    required this.shape,
    required this.allEntries,
    required this.absoluteIndex,
  });
  final InkChartModel entry;
  final InkSwatchShape shape;
  final List<InkChartModel> allEntries;
  final int absoluteIndex;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => _showDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: InkShapeClip(
              shape: shape,
              child: CachedNetworkImage(
                imageUrl: entry.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: const Color(0xFFD4C5A9)),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0xFFD4C5A9),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Text(
                  entry.brand,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  entry.inkName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: InkDetailCarousel(
          itemCount: allEntries.length,
          initialIndex: absoluteIndex,
          pageBuilder: (c, i) =>
              _ReadonlyDetailPage(entry: allEntries[i], shape: shape),
        ),
      ),
    );
  }
}

// ── 읽기 전용 상세 페이지 (삭제 버튼 없음) ──────────────────────────────────

class _ReadonlyDetailPage extends StatelessWidget {
  const _ReadonlyDetailPage({required this.entry, required this.shape});
  final InkChartModel entry;
  final InkSwatchShape shape;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dateStr = DateFormat('yyyy년 M월 d일').format(entry.createdAt);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: screenW * 0.68,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: InkShapeClip(
                  shape: shape,
                  child: CachedNetworkImage(
                    imageUrl: entry.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.chipBackground),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.chipBackground,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 1.5, color: AppColors.divider),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.brand,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.inkName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dateStr,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              if (entry.memo.isNotEmpty ||
                  (entry.contentBlocks?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '메모',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkMemoContent(entry: entry),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
