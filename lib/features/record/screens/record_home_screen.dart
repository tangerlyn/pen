import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../mypage/providers/ink_shape_provider.dart';
import '../providers/my_records_provider.dart';
import '../widgets/record_views.dart';

/// 첫 탭 "기록" — 내가 기록한 스와치(마이페이지 잉크 차트 포함)를 그리드/타임라인으로.
/// 기록이 없으면 첫 스와치 기록을 안내한다. 기존 디스커버리 피드는 `/discover`.
class RecordHomeScreen extends ConsumerStatefulWidget {
  const RecordHomeScreen({super.key});

  @override
  ConsumerState<RecordHomeScreen> createState() => _RecordHomeScreenState();
}

class _RecordHomeScreenState extends ConsumerState<RecordHomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openRecord(String entry) => context.push('/record/new?entry=$entry');

  void _openDetail(InkRecord r) => context.push('/record/${r.book.id}/${r.entry.id}');

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(scrollToTopTabProvider, (_, next) {
      if (next == 0) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        ref.read(scrollToTopTabProvider.notifier).state = null;
      }
    });

    final recordsAsync = ref.watch(myInkRecordsProvider);
    final records = recordsAsync.valueOrNull;
    final viewMode = ref.watch(recordViewModeProvider);
    final shape = ref.watch(inkSwatchShapeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('내 잉크 기록'),
            actions: [
              IconButton(
                tooltip: '둘러보기',
                icon: const Icon(Icons.explore_outlined),
                onPressed: () => context.push('/discover'),
              ),
              IconButton(
                tooltip: '검색',
                icon: const Icon(Icons.search),
                onPressed: () => context.push('/search?type=all'),
              ),
              const NotificationBell(),
            ],
          ),
          ...switch (recordsAsync) {
            _ when records != null && records.isEmpty => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: RecordEmptyState(
                    onRecord: () => _openRecord('empty_state'),
                    onBrowseArchive: () => context.go('/archive'),
                    onDiscover: () => context.push('/discover'),
                  ),
                ),
              ],
            _ when records != null => [
                SliverToBoxAdapter(
                  child: _RecordSummaryBar(
                    records: records,
                    viewMode: viewMode,
                    onViewMode: ref.read(recordViewModeProvider.notifier).set,
                  ),
                ),
                if (viewMode == RecordViewMode.grid)
                  RecordGrid(records: records, shape: shape, onTap: _openDetail)
                else
                  RecordTimeline(records: records, shape: shape, onTap: _openDetail),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            AsyncError() => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('기록을 불러오지 못했어요', style: AppTextStyles.bodyMedium),
                        TextButton(
                          onPressed: () => ref.invalidate(myInkRecordsProvider),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            _ => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
          },
        ],
      ),
      floatingActionButton: (records?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              heroTag: 'record_home_fab',
              onPressed: () => _openRecord('home'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('스와치 기록'),
            )
          : null,
    );
  }
}

class _RecordSummaryBar extends StatelessWidget {
  const _RecordSummaryBar({
    required this.records,
    required this.viewMode,
    required this.onViewMode,
  });

  final List<InkRecord> records;
  final RecordViewMode viewMode;
  final ValueChanged<RecordViewMode> onViewMode;

  @override
  Widget build(BuildContext context) {
    final inkCount = records
        .map((r) => r.entry.inkId ?? '${r.entry.brand}|${r.entry.inkName}'.toLowerCase())
        .toSet()
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '스와치 ${records.length}개 · 잉크 $inkCount종',
              style: AppTextStyles.labelLarge,
            ),
          ),
          IconButton(
            tooltip: '그리드로 보기',
            isSelected: viewMode == RecordViewMode.grid,
            color: AppColors.textSecondary,
            selectedIcon: const Icon(Icons.grid_view, color: AppColors.primary),
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => onViewMode(RecordViewMode.grid),
          ),
          IconButton(
            tooltip: '타임라인으로 보기',
            isSelected: viewMode == RecordViewMode.timeline,
            color: AppColors.textSecondary,
            selectedIcon: const Icon(Icons.view_agenda, color: AppColors.primary),
            icon: const Icon(Icons.view_agenda_outlined),
            onPressed: () => onViewMode(RecordViewMode.timeline),
          ),
        ],
      ),
    );
  }
}
