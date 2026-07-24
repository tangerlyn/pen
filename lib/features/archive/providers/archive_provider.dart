import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/providers/providers.dart';

enum ArchiveSortOption {
  defaultOrder('기본순'),
  rating('별점순'),
  popular('인기순');

  const ArchiveSortOption(this.label);
  final String label;
}

class InkFilter {
  const InkFilter({
    this.brand,
    this.colorFamilies = const [],
    this.inkTypes = const [],
    this.capacityRange,
  });
  final String? brand;
  final List<String> colorFamilies;
  final List<String> inkTypes;
  final String? capacityRange;

  InkFilter copyWith({
    String? brand,
    List<String>? colorFamilies,
    List<String>? inkTypes,
    String? capacityRange,
  }) {
    return InkFilter(
      brand: brand ?? this.brand,
      colorFamilies: colorFamilies ?? this.colorFamilies,
      inkTypes: inkTypes ?? this.inkTypes,
      capacityRange: capacityRange ?? this.capacityRange,
    );
  }
}

class PenFilter {
  const PenFilter({this.brand, this.nibSize, this.nibMaterial, this.fillType});
  final String? brand;
  final String? nibSize;
  final String? nibMaterial;
  final String? fillType;
}

class ArchiveState {
  const ArchiveState({
    this.tabIndex = 0,
    this.search = '',
    this.inks = const [],
    this.pens = const [],
    this.rawInks = const [],
    this.rawPens = const [],
    this.isLoading = false,
    this.inkFilter = const InkFilter(),
    this.penFilter = const PenFilter(),
    this.inkSort = ArchiveSortOption.defaultOrder,
    this.penSort = ArchiveSortOption.defaultOrder,
  });

  final int tabIndex;
  final String search;
  final List<InkModel> inks;
  final List<PenModel> pens;
  final List<InkModel> rawInks;
  final List<PenModel> rawPens;
  final bool isLoading;
  final InkFilter inkFilter;
  final PenFilter penFilter;
  final ArchiveSortOption inkSort;
  final ArchiveSortOption penSort;

  ArchiveState copyWith({
    int? tabIndex,
    String? search,
    List<InkModel>? inks,
    List<PenModel>? pens,
    List<InkModel>? rawInks,
    List<PenModel>? rawPens,
    bool? isLoading,
    InkFilter? inkFilter,
    PenFilter? penFilter,
    ArchiveSortOption? inkSort,
    ArchiveSortOption? penSort,
  }) {
    return ArchiveState(
      tabIndex: tabIndex ?? this.tabIndex,
      search: search ?? this.search,
      inks: inks ?? this.inks,
      pens: pens ?? this.pens,
      rawInks: rawInks ?? this.rawInks,
      rawPens: rawPens ?? this.rawPens,
      isLoading: isLoading ?? this.isLoading,
      inkFilter: inkFilter ?? this.inkFilter,
      penFilter: penFilter ?? this.penFilter,
      inkSort: inkSort ?? this.inkSort,
      penSort: penSort ?? this.penSort,
    );
  }
}

class ArchiveNotifier extends StateNotifier<ArchiveState> {
  ArchiveNotifier(this._ref) : super(const ArchiveState()) {
    // 첫 build() 도중 동기 상태 변경이 Flutter 렌더 파이프라인을 깨지 않도록
    // microtask로 미뤄서 현재 프레임이 완전히 끝난 뒤에 로드 시작
    Future.microtask(_load);
  }

  final Ref _ref;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(archiveRepoProvider);
      switch (state.tabIndex) {
        case 0:
          final raw = await repo.getInks(
            brand: state.inkFilter.brand,
            colorFamilies: state.inkFilter.colorFamilies.isNotEmpty ? state.inkFilter.colorFamilies : null,
            inkTypes: state.inkFilter.inkTypes.isNotEmpty ? state.inkFilter.inkTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
          );
          state = state.copyWith(rawInks: raw, inks: _sortInks(raw, state.inkSort), isLoading: false);
        case 1:
          final raw = await repo.getPens(
            brand: state.penFilter.brand,
            nibSize: state.penFilter.nibSize,
            nibMaterial: state.penFilter.nibMaterial,
            fillType: state.penFilter.fillType,
            search: state.search.isNotEmpty ? state.search : null,
          );
          state = state.copyWith(rawPens: raw, pens: _sortPens(raw, state.penSort), isLoading: false);
      }
    } catch (e, st) {
      debugPrint('ArchiveNotifier._load error: $e');
      debugPrint('$st');
      state = state.copyWith(isLoading: false);
    }
  }

  void setTab(int index) {
    state = state.copyWith(tabIndex: index);
    _load();
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
    _load();
  }

  void setInkFilter(InkFilter filter) {
    state = state.copyWith(inkFilter: filter);
    _load();
  }

  void setPenFilter(PenFilter filter) {
    state = state.copyWith(penFilter: filter);
    _load();
  }

  void setInkSort(ArchiveSortOption sort) {
    state = state.copyWith(
      inkSort: sort,
      inks: _sortInks(state.rawInks, sort),
    );
  }

  void setPenSort(ArchiveSortOption sort) {
    state = state.copyWith(
      penSort: sort,
      pens: _sortPens(state.rawPens, sort),
    );
  }

  List<InkModel> _sortInks(List<InkModel> list, ArchiveSortOption sort) {
    final sorted = [...list];
    switch (sort) {
      case ArchiveSortOption.rating:
        sorted.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      case ArchiveSortOption.popular:
        sorted.sort((a, b) {
          final cmp = b.reviewCount.compareTo(a.reviewCount);
          if (cmp != 0) return cmp;
          return b.avgRating.compareTo(a.avgRating);
        });
      case ArchiveSortOption.defaultOrder:
        sorted.sort((a, b) => _compareInkName(a.name, b.name));
    }
    return sorted;
  }

  /// 한글 이름은 가나다순으로 먼저, 영어/숫자로 시작하는 이름은 뒤로 빼서
  /// 그 안에서 알파벳/숫자 순으로 정렬
  int _compareInkName(String a, String b) {
    final aKorean = _startsWithKorean(a);
    final bKorean = _startsWithKorean(b);
    if (aKorean != bKorean) return aKorean ? -1 : 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  bool _startsWithKorean(String s) {
    if (s.isEmpty) return false;
    final code = s.codeUnitAt(0);
    return code >= 0xAC00 && code <= 0xD7A3;
  }

  List<PenModel> _sortPens(List<PenModel> list, ArchiveSortOption sort) {
    final sorted = [...list];
    switch (sort) {
      case ArchiveSortOption.rating:
        sorted.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      case ArchiveSortOption.popular:
        sorted.sort((a, b) {
          final cmp = b.reviewCount.compareTo(a.reviewCount);
          if (cmp != 0) return cmp;
          return b.avgRating.compareTo(a.avgRating);
        });
      case ArchiveSortOption.defaultOrder:
        break;
    }
    return sorted;
  }
}

final archiveProvider = StateNotifierProvider<ArchiveNotifier, ArchiveState>((ref) {
  return ArchiveNotifier(ref);
});
