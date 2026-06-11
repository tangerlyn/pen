import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/widgets/common/skeletons.dart';
import '../../../shared/widgets/community/post_card.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../providers/search_provider.dart';
import '../providers/suggestion_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.type});
  final String type; // 'review', 'community', 'all'

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _ctrl;
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider(widget.type).notifier).reset();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _doSearch(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    setState(() => _showSuggestions = false);
    ref.read(searchHistoryProvider.notifier).add(q);
    ref.read(searchProvider(widget.type).notifier).search(q);
    _focusNode.unfocus();
  }

  void _tapSuggestion(String s) {
    _ctrl.text = s;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: s.length));
    _doSearch(s);
  }

  void _tapHistory(String query) {
    _ctrl.text = query;
    _doSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final hasSearched = ref.watch(
        searchProvider(widget.type).select((s) => s.hasSearched));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _SearchAppBar(
        ctrl: _ctrl,
        focusNode: _focusNode,
        onSubmitted: _doSearch,
        onChanged: (v) {
          if (v.trim().isEmpty) {
            ref.read(searchProvider(widget.type).notifier).reset();
          }
          setState(() => _showSuggestions = v.trim().isNotEmpty);
        },
      ),
      body: _showSuggestions
          ? _SuggestionsView(
              query: _ctrl.text.trim(),
              onTap: _tapSuggestion,
            )
          : !hasSearched
              ? _HistoryView(
                  history: history,
                  onTap: _tapHistory,
                  onRemove: (q) =>
                      ref.read(searchHistoryProvider.notifier).remove(q),
                  onClear: () =>
                      ref.read(searchHistoryProvider.notifier).clear(),
                )
              : _ResultsView(type: widget.type),
    );
  }
}

// ── 검색 AppBar ───────────────────────────────────────────────────────
class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SearchAppBar({
    required this.ctrl,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
  });

  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: const BackButton(),
      titleSpacing: 0,
      title: TextField(
        controller: ctrl,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: '검색어를 입력하세요',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        ),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (ctrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              ctrl.clear();
              onChanged('');
              focusNode.requestFocus();
            },
          ),
      ],
    );
  }
}

// ── 연관검색어 ────────────────────────────────────────────────────────
class _SuggestionsView extends ConsumerWidget {
  const _SuggestionsView({required this.query, required this.onTap});
  final String query;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionProvider(query));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            leading: const Icon(Icons.search,
                size: 18, color: AppColors.textTertiary),
            title: Text(suggestions[i],
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary)),
            onTap: () => onTap(suggestions[i]),
          ),
        );
      },
    );
  }
}

// ── 최근 검색어 ───────────────────────────────────────────────────────
class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.history,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          '최근 검색어가 없어요',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Text(
                '최근 검색어',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('전체 삭제', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (_, i) {
              final q = history[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history,
                    size: 18, color: AppColors.textTertiary),
                title: Text(q,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                trailing: IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: AppColors.textTertiary),
                  onPressed: () => onRemove(q),
                ),
                onTap: () => onTap(q),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 검색 결과 ─────────────────────────────────────────────────────────
class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider(type));

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text('오류가 발생했어요\n${state.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    if (state.hasSearched && state.reviews.isEmpty && state.posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('검색 결과가 없어요',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            SizedBox(height: 6),
            Text('다른 검색어로 시도해보세요',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    if (type == 'review') {
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            ref.read(searchProvider(type).notifier).loadMore();
          }
          return false;
        },
        child: Column(
          children: [
            _ReviewSortChip(type: type),
            Expanded(
              child: _ReviewGrid(
                reviews: state.reviews,
                isLoadingMore: state.isLoadingMore,
              ),
            ),
          ],
        ),
      );
    }
    if (type == 'community') {
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            ref.read(searchProvider(type).notifier).loadMore();
          }
          return false;
        },
        child: Column(
          children: [
            _PostSortChip(type: type),
            Expanded(
              child: _PostList(
                posts: state.posts,
                isLoadingMore: state.isLoadingMore,
              ),
            ),
          ],
        ),
      );
    }

    // type == 'all': 섹션 분리 (페이지네이션 없음)
    return ListView(
      children: [
        if (state.reviews.isNotEmpty) ...[
          _SectionHeader(title: '리뷰', count: state.reviews.length),
          _ReviewsHorizontal(reviews: state.reviews),
        ],
        if (state.posts.isNotEmpty) ...[
          _SectionHeader(title: '커뮤니티', count: state.posts.length),
          ...state.posts.map((post) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PostCard(
                    post: post,
                    onTap: () => context.push('/community/${post.id}'),
                  ),
                  const Divider(height: 1),
                ],
              )),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── 정렬 칩 (단일 칩 → 바텀시트) ─────────────────────────────────────
class _ReviewSortChip extends ConsumerWidget {
  const _ReviewSortChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(searchProvider(type).select((s) => s.reviewSort));
    return _SortChipRow(
      label: current.label,
      isActive: current != ReviewSortOption.newest,
      onTap: () => _showPicker(context, ref, current),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, ReviewSortOption current) {
    _showSortSheet(
      context: context,
      options: ReviewSortOption.values.map((o) => o.label).toList(),
      currentIndex: ReviewSortOption.values.indexOf(current),
      onSelected: (i) => ref
          .read(searchProvider(type).notifier)
          .setReviewSort(ReviewSortOption.values[i]),
    );
  }
}

class _PostSortChip extends ConsumerWidget {
  const _PostSortChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(searchProvider(type).select((s) => s.postSort));
    return _SortChipRow(
      label: current.label,
      isActive: current != PostSortOption.newest,
      onTap: () => _showPicker(context, ref, current),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, PostSortOption current) {
    _showSortSheet(
      context: context,
      options: PostSortOption.values.map((o) => o.label).toList(),
      currentIndex: PostSortOption.values.indexOf(current),
      onSelected: (i) => ref
          .read(searchProvider(type).notifier)
          .setPostSort(PostSortOption.values[i]),
    );
  }
}

// 정렬 칩 행 — 좌측 정렬로 단일 칩 표시
class _SortChipRow extends StatelessWidget {
  const _SortChipRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.chipSelected : AppColors.chipBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.swap_vert,
                  size: 15,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showSortSheet({
  required BuildContext context,
  required List<String> options,
  required int currentIndex,
  required ValueChanged<int> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('정렬',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const Divider(height: 1),
          ...options.asMap().entries.map(
                (e) => ListTile(
                  title: Text(e.value),
                  trailing: e.key == currentIndex
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(e.key);
                  },
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('$count건',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ── 리뷰 그리드 (type=review) ─────────────────────────────────────────
class _ReviewGrid extends StatelessWidget {
  const _ReviewGrid({required this.reviews, this.isLoadingMore = false});
  final List<ReviewModel> reviews;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    final itemCount = reviews.length + (isLoadingMore ? 2 : 0);
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (i >= reviews.length) return const ReviewGridSkeleton();
        return ReviewFeedCard(
          review: reviews[i],
          onTap: () => context.push('/review/${reviews[i].id}'),
        );
      },
    );
  }
}

// ── 리뷰 가로 스크롤 (type=all) ───────────────────────────────────────
class _ReviewsHorizontal extends StatelessWidget {
  const _ReviewsHorizontal({required this.reviews});
  final List<ReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reviews.length,
        itemBuilder: (_, i) {
          final r = reviews[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: SizedBox(
              width: 140,
              child: ReviewFeedCard(
                review: r,
                onTap: () => context.push('/review/${r.id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 게시글 리스트 (type=community) ────────────────────────────────────
class _PostList extends StatelessWidget {
  const _PostList({required this.posts, this.isLoadingMore = false});
  final List<PostModel> posts;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: posts.length + (isLoadingMore ? 1 : 0),
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i >= posts.length) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return PostCard(
          post: posts[i],
          onTap: () => context.push('/community/${posts[i].id}'),
        );
      },
    );
  }
}
