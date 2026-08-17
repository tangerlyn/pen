import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.brands = const [],
    this.colorFamilies = const [],
    this.inkTypes = const [],
    this.capacityRange,
  });
  final List<String> brands;
  final List<String> colorFamilies;
  final List<String> inkTypes;
  final String? capacityRange;

  InkFilter copyWith({
    List<String>? brands,
    List<String>? colorFamilies,
    List<String>? inkTypes,
    String? capacityRange,
  }) {
    return InkFilter(
      brands: brands ?? this.brands,
      colorFamilies: colorFamilies ?? this.colorFamilies,
      inkTypes: inkTypes ?? this.inkTypes,
      capacityRange: capacityRange ?? this.capacityRange,
    );
  }
}

class PenFilter {
  const PenFilter({
    this.brands = const [],
    this.nibSize,
    this.nibMaterial,
    this.fillType,
  });
  final List<String> brands;
  final String? nibSize;
  final String? nibMaterial;
  final String? fillType;

  PenFilter copyWith({
    List<String>? brands,
    String? nibSize,
    String? nibMaterial,
    String? fillType,
  }) {
    return PenFilter(
      brands: brands ?? this.brands,
      nibSize: nibSize ?? this.nibSize,
      nibMaterial: nibMaterial ?? this.nibMaterial,
      fillType: fillType ?? this.fillType,
    );
  }
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
    this.inkLastDoc,
    this.penLastDoc,
    this.inkHasMore = false,
    this.penHasMore = false,
    this.isLoadingMoreInks = false,
    this.isLoadingMorePens = false,
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
  // 무필터 브라우징 시 다음 페이지를 이어 불러오기 위한 커서 — 검색/브랜드/
  // 색상계열 필터가 있을 때는 리포지토리가 전체를 한 번에 가져오므로 null
  final DocumentSnapshot? inkLastDoc;
  final DocumentSnapshot? penLastDoc;
  final bool inkHasMore;
  final bool penHasMore;
  final bool isLoadingMoreInks;
  final bool isLoadingMorePens;

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
    // DocumentSnapshot?는 "다음 페이지 없음"을 나타내는 null도 유효한 값이라,
    // 일반적인 `?? this.field` 패턴으로는 "안 넘김"과 "명시적으로 null로
    // 리셋"을 구분할 수 없다. _unset 센티널로 "이 파라미터를 아예 안 넘겼을
    // 때만" 기존 값을 유지하도록 구분한다.
    Object? inkLastDoc = _unset,
    Object? penLastDoc = _unset,
    bool? inkHasMore,
    bool? penHasMore,
    bool? isLoadingMoreInks,
    bool? isLoadingMorePens,
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
      inkLastDoc: identical(inkLastDoc, _unset)
          ? this.inkLastDoc
          : inkLastDoc as DocumentSnapshot?,
      penLastDoc: identical(penLastDoc, _unset)
          ? this.penLastDoc
          : penLastDoc as DocumentSnapshot?,
      inkHasMore: inkHasMore ?? this.inkHasMore,
      penHasMore: penHasMore ?? this.penHasMore,
      isLoadingMoreInks: isLoadingMoreInks ?? this.isLoadingMoreInks,
      isLoadingMorePens: isLoadingMorePens ?? this.isLoadingMorePens,
    );
  }
}

const _unset = Object();

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
          final result = await repo.getInks(
            brands: state.inkFilter.brands.isNotEmpty ? state.inkFilter.brands : null,
            colorFamilies: state.inkFilter.colorFamilies.isNotEmpty ? state.inkFilter.colorFamilies : null,
            inkTypes: state.inkFilter.inkTypes.isNotEmpty ? state.inkFilter.inkTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
          );
          state = state.copyWith(
            rawInks: result.items,
            inks: _sortInks(result.items, state.inkSort),
            isLoading: false,
            inkLastDoc: result.lastDoc,
            inkHasMore: result.hasMore,
          );
        case 1:
          final result = await repo.getPens(
            brands: state.penFilter.brands.isNotEmpty ? state.penFilter.brands : null,
            nibSize: state.penFilter.nibSize,
            nibMaterial: state.penFilter.nibMaterial,
            fillType: state.penFilter.fillType,
            search: state.search.isNotEmpty ? state.search : null,
          );
          state = state.copyWith(
            rawPens: result.items,
            pens: _sortPens(result.items, state.penSort),
            isLoading: false,
            penLastDoc: result.lastDoc,
            penHasMore: result.hasMore,
          );
      }
    } catch (e, st) {
      debugPrint('ArchiveNotifier._load error: $e');
      debugPrint('$st');
      state = state.copyWith(isLoading: false);
    }
  }

  /// 무필터 브라우징 중 스크롤이 끝에 닿으면 다음 페이지를 이어붙인다.
  /// 검색/브랜드/색상계열 필터가 걸려있을 땐 첫 로드에서 이미 전체를
  /// 가져온 상태라(hasMore=false) 아무 것도 하지 않는다.
  Future<void> loadMore() async {
    final repo = _ref.read(archiveRepoProvider);
    switch (state.tabIndex) {
      case 0:
        if (!state.inkHasMore || state.isLoadingMoreInks || state.isLoading) {
          return;
        }
        state = state.copyWith(isLoadingMoreInks: true);
        try {
          final result = await repo.getInks(
            brands: state.inkFilter.brands.isNotEmpty ? state.inkFilter.brands : null,
            colorFamilies: state.inkFilter.colorFamilies.isNotEmpty ? state.inkFilter.colorFamilies : null,
            inkTypes: state.inkFilter.inkTypes.isNotEmpty ? state.inkFilter.inkTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
            lastDoc: state.inkLastDoc,
          );
          final merged = [...state.rawInks, ...result.items];
          state = state.copyWith(
            rawInks: merged,
            inks: _sortInks(merged, state.inkSort),
            inkLastDoc: result.lastDoc,
            inkHasMore: result.hasMore,
            isLoadingMoreInks: false,
          );
        } catch (e, st) {
          debugPrint('ArchiveNotifier.loadMore(ink) error: $e');
          debugPrint('$st');
          state = state.copyWith(isLoadingMoreInks: false);
        }
      case 1:
        if (!state.penHasMore || state.isLoadingMorePens || state.isLoading) {
          return;
        }
        state = state.copyWith(isLoadingMorePens: true);
        try {
          final result = await repo.getPens(
            brands: state.penFilter.brands.isNotEmpty ? state.penFilter.brands : null,
            nibSize: state.penFilter.nibSize,
            nibMaterial: state.penFilter.nibMaterial,
            fillType: state.penFilter.fillType,
            search: state.search.isNotEmpty ? state.search : null,
            lastDoc: state.penLastDoc,
          );
          final merged = [...state.rawPens, ...result.items];
          state = state.copyWith(
            rawPens: merged,
            pens: _sortPens(merged, state.penSort),
            penLastDoc: result.lastDoc,
            penHasMore: result.hasMore,
            isLoadingMorePens: false,
          );
        } catch (e, st) {
          debugPrint('ArchiveNotifier.loadMore(pen) error: $e');
          debugPrint('$st');
          state = state.copyWith(isLoadingMorePens: false);
        }
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
        sorted.sort((a, b) => _compareProductName(a.name, b.name));
    }
    return sorted;
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
        sorted.sort((a, b) => _compareProductName(a.modelName, b.modelName));
    }
    return sorted;
  }
}

final archiveProvider = StateNotifierProvider<ArchiveNotifier, ArchiveState>((ref) {
  return ArchiveNotifier(ref);
});

/// 한글 이름은 가나다순으로 먼저, 영어/숫자로 시작하는 이름은 뒤로 빼서
/// 그 안에서 알파벳/숫자 순으로 정렬
int _compareProductName(String a, String b) {
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

// ── 브랜드 필터 옵션 — 현재 등록된 잉크/만년필의 브랜드 목록(중복 제거, 이름순 정렬) ──
final inkBrandsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(archiveRepoProvider);
  final suggestions = await repo.getInkFieldSuggestions();
  final brands = [...suggestions.brands];
  brands.sort(_compareProductName);
  return brands;
});

final penBrandsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(archiveRepoProvider);
  final brands = await repo.getPenBrands();
  brands.sort(_compareProductName);
  return brands;
});
