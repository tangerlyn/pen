import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart';
import '../../search/providers/suggestion_provider.dart';
import '../widgets/pen_list_tile.dart';

// ── 아카이브 검색 히스토리 ────────────────────────────────────────────
class _ArchiveHistoryNotifier extends StateNotifier<List<String>> {
  static const _key = 'archive_search_history';
  static const _max = 20;

  _ArchiveHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getStringList(_key) ?? [];
  }

  Future<void> add(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final list = [
      trimmed,
      ...state.where((s) => s != trimmed),
    ].take(_max).toList();
    state = list;
    (await SharedPreferences.getInstance()).setStringList(_key, list);
  }

  Future<void> remove(String q) async {
    final list = state.where((s) => s != q).toList();
    state = list;
    (await SharedPreferences.getInstance()).setStringList(_key, list);
  }

  Future<void> clear() async {
    state = [];
    (await SharedPreferences.getInstance()).remove(_key);
  }
}

final _archiveHistoryProvider =
    StateNotifierProvider<_ArchiveHistoryNotifier, List<String>>(
      (_) => _ArchiveHistoryNotifier(),
    );

// ── 검색 화면 ─────────────────────────────────────────────────────────
class ArchiveSearchScreen extends ConsumerStatefulWidget {
  const ArchiveSearchScreen({super.key});

  @override
  ConsumerState<ArchiveSearchScreen> createState() =>
      _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends ConsumerState<ArchiveSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _hasSearched = false;
  bool _isLoading = false;
  List<InkModel> _inks = [];
  List<PenModel> _pens = [];
  int _searchGen = 0;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    ref.read(_archiveHistoryProvider.notifier).add(query);
    _lastQuery = query;
    final gen = ++_searchGen;
    setState(() {
      _hasSearched = true;
      _isLoading = true;
    });
    try {
      final repo = ref.read(archiveRepoProvider);
      final inks = await repo.getInks(search: query, limit: 100);
      final pens = await repo.getPens(search: query, limit: 100);
      if (mounted && gen == _searchGen) {
        setState(() {
          _inks = inks;
          _pens = pens;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && gen == _searchGen) setState(() => _isLoading = false);
    }
  }

  void _tapSuggestion(String s) {
    _ctrl.text = s;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: s.length),
    );
    _doSearch(s);
  }

  void _tapHistory(String q) {
    _ctrl.text = q;
    _doSearch(q);
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _hasSearched = false;
      _inks = [];
      _pens = [];
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    final history = ref.watch(_archiveHistoryProvider);

    final showSuggestions = !_hasSearched && query.isNotEmpty;
    final showHistory = !_hasSearched && query.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _doSearch,
          onChanged: (_) => setState(() => _hasSearched = false),
          decoration: const InputDecoration(
            hintText: '브랜드명, 제품명으로 검색',
            hintStyle: TextStyle(fontSize: 15, color: AppColors.textTertiary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _clear,
            ),
        ],
      ),
      body: showSuggestions
          ? _SuggestionsView(query: query, onTap: _tapSuggestion)
          : showHistory
          ? _HistoryView(
              history: history,
              onTap: _tapHistory,
              onRemove: (q) =>
                  ref.read(_archiveHistoryProvider.notifier).remove(q),
              onClear: () => ref.read(_archiveHistoryProvider.notifier).clear(),
            )
          : _ResultsView(
              tabController: _tabController,
              inks: _inks,
              pens: _pens,
              isLoading: _isLoading,
              query: _lastQuery,
            ),
    );
  }
}

// ── 연관검색어 뷰 ─────────────────────────────────────────────────────
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
            leading: const Icon(
              Icons.search,
              size: 18,
              color: AppColors.textTertiary,
            ),
            title: Text(suggestions[i], style: AppTextStyles.bodyMedium),
            onTap: () => onTap(suggestions[i]),
          ),
        );
      },
    );
  }
}

// ── 최근 검색어 뷰 ────────────────────────────────────────────────────
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
      return Center(
        child: Text(
          '최근 검색어가 없어요',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
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
              Text(
                '최근 검색어',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
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
                leading: const Icon(
                  Icons.history,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                title: Text(q, style: AppTextStyles.bodyMedium),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
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

// ── 결과 뷰 ───────────────────────────────────────────────────────────
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.tabController,
    required this.inks,
    required this.pens,
    required this.isLoading,
    required this.query,
  });
  final TabController tabController;
  final List<InkModel> inks;
  final List<PenModel> pens;
  final bool isLoading;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        TabBar(
          controller: tabController,
          tabs: [
            Tab(text: inks.isEmpty ? '잉크' : '잉크 (${inks.length})'),
            Tab(text: pens.isEmpty ? '만년필' : '만년필 (${pens.length})'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _InkResults(inks: inks, query: query),
              _PenResults(pens: pens, query: query),
            ],
          ),
        ),
      ],
    );
  }
}

class _InkResults extends StatelessWidget {
  const _InkResults({required this.inks, required this.query});
  final List<InkModel> inks;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (inks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '잉크 검색 결과가 없어요',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: Text('"$query" 직접 등록하기'),
              onPressed: () => showAddProductSheet(
                context,
                initialType: 'ink',
                initialName: query,
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: inks.length,
      itemBuilder: (_, i) {
        final ink = inks[i];
        return GestureDetector(
          onTap: () => context.push('/archive/ink/${ink.id}'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ink.inkColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: ink.inkColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ink.name,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PenResults extends StatelessWidget {
  const _PenResults({required this.pens, required this.query});
  final List<PenModel> pens;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (pens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '만년필 검색 결과가 없어요',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: Text('"$query" 직접 등록하기'),
              onPressed: () => showAddProductSheet(
                context,
                initialType: 'pen',
                initialName: query,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: pens.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => PenListTile(
        pen: pens[i],
        onTap: () => context.push('/archive/pen/${pens[i].id}'),
      ),
    );
  }
}
