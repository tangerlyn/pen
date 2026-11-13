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
    this.fillTypes = const [],
  });
  final List<String> brands;
  final String? nibSize;
  final String? nibMaterial;
  final List<String> fillTypes;

  PenFilter copyWith({
    List<String>? brands,
    String? nibSize,
    String? nibMaterial,
    List<String>? fillTypes,
  }) {
    return PenFilter(
      brands: brands ?? this.brands,
      nibSize: nibSize ?? this.nibSize,
      nibMaterial: nibMaterial ?? this.nibMaterial,
      fillTypes: fillTypes ?? this.fillTypes,
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
    this.isLoadingInks = false,
    this.isLoadingPens = false,
    this.inkLoadFailed = false,
    this.penLoadFailed = false,
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
  // 탭별로 따로 관리 — 한쪽 탭 로드가 끝났다고 다른 탭의 로딩 표시가 꺼지지 않게
  final bool isLoadingInks;
  final bool isLoadingPens;
  // 마지막 로드가 실패했는지 — "결과 없음"과 구분해서 다시 시도 버튼을 보여준다
  final bool inkLoadFailed;
  final bool penLoadFailed;
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
    bool? isLoadingInks,
    bool? isLoadingPens,
    bool? inkLoadFailed,
    bool? penLoadFailed,
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
      isLoadingInks: isLoadingInks ?? this.isLoadingInks,
      isLoadingPens: isLoadingPens ?? this.isLoadingPens,
      inkLoadFailed: inkLoadFailed ?? this.inkLoadFailed,
      penLoadFailed: penLoadFailed ?? this.penLoadFailed,
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
  ArchiveNotifier(this._ref) : super(const ArchiveState(isLoadingInks: true)) {
    // 첫 build() 도중 동기 상태 변경이 Flutter 렌더 파이프라인을 깨지 않도록
    // microtask로 미뤄서 현재 프레임이 완전히 끝난 뒤에 로드 시작
    Future.microtask(_load);
  }

  final Ref _ref;

  // 탭별 요청 세대 — 필터/검색을 빠르게 바꾸면 이전 요청이 나중에 끝나서
  // 최신 결과를 덮어쓸 수 있어, 가장 마지막 요청의 결과만 반영한다.
  int _inkGen = 0;
  int _penGen = 0;

  Future<void> _load() async {
    final repo = _ref.read(archiveRepoProvider);
    switch (state.tabIndex) {
      case 0:
        final gen = ++_inkGen;
        state = state.copyWith(isLoadingInks: true, inkLoadFailed: false);
        try {
          final result = await repo.getInks(
            brands: state.inkFilter.brands.isNotEmpty ? state.inkFilter.brands : null,
            colorFamilies: state.inkFilter.colorFamilies.isNotEmpty ? state.inkFilter.colorFamilies : null,
            inkTypes: state.inkFilter.inkTypes.isNotEmpty ? state.inkFilter.inkTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
          );
          if (!mounted || gen != _inkGen) return;
          state = state.copyWith(
            rawInks: result.items,
            inks: _sortInks(result.items, state.inkSort),
            isLoadingInks: false,
            inkLastDoc: result.lastDoc,
            inkHasMore: result.hasMore,
          );
        } catch (e, st) {
          debugPrint('ArchiveNotifier._load(ink) error: $e');
          debugPrint('$st');
          if (!mounted || gen != _inkGen) return;
          state = state.copyWith(
            isLoadingInks: false,
            inkLoadFailed: true,
            rawInks: const [],
            inks: const [],
            inkLastDoc: null,
            inkHasMore: false,
          );
        }
      case 1:
        final gen = ++_penGen;
        state = state.copyWith(isLoadingPens: true, penLoadFailed: false);
        try {
          final result = await repo.getPens(
            brands: state.penFilter.brands.isNotEmpty ? state.penFilter.brands : null,
            nibSize: state.penFilter.nibSize,
            nibMaterial: state.penFilter.nibMaterial,
            fillTypes: state.penFilter.fillTypes.isNotEmpty ? state.penFilter.fillTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
          );
          if (!mounted || gen != _penGen) return;
          state = state.copyWith(
            rawPens: result.items,
            pens: _sortPens(result.items, state.penSort),
            isLoadingPens: false,
            penLastDoc: result.lastDoc,
            penHasMore: result.hasMore,
          );
        } catch (e, st) {
          debugPrint('ArchiveNotifier._load(pen) error: $e');
          debugPrint('$st');
          if (!mounted || gen != _penGen) return;
          state = state.copyWith(
            isLoadingPens: false,
            penLoadFailed: true,
            rawPens: const [],
            pens: const [],
            penLastDoc: null,
            penHasMore: false,
          );
        }
    }
  }

  /// 무필터 브라우징 중 스크롤이 끝에 닿으면 다음 페이지를 이어붙인다.
  /// 검색/브랜드/색상계열 필터가 걸려있을 땐 첫 로드에서 이미 전체를
  /// 가져온 상태라(hasMore=false) 아무 것도 하지 않는다.
  Future<void> loadMore() async {
    final repo = _ref.read(archiveRepoProvider);
    switch (state.tabIndex) {
      case 0:
        if (!state.inkHasMore || state.isLoadingMoreInks || state.isLoadingInks) {
          return;
        }
        final gen = _inkGen;
        state = state.copyWith(isLoadingMoreInks: true);
        try {
          final result = await repo.getInks(
            brands: state.inkFilter.brands.isNotEmpty ? state.inkFilter.brands : null,
            colorFamilies: state.inkFilter.colorFamilies.isNotEmpty ? state.inkFilter.colorFamilies : null,
            inkTypes: state.inkFilter.inkTypes.isNotEmpty ? state.inkFilter.inkTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
            lastDoc: state.inkLastDoc,
          );
          if (!mounted) return;
          // 그 사이 필터/검색이 바뀌어 새 로드가 시작됐으면 이전 목록에 이어붙이지 않는다
          if (gen != _inkGen) {
            state = state.copyWith(isLoadingMoreInks: false);
            return;
          }
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
          if (!mounted) return;
          state = state.copyWith(isLoadingMoreInks: false);
        }
      case 1:
        if (!state.penHasMore || state.isLoadingMorePens || state.isLoadingPens) {
          return;
        }
        final gen = _penGen;
        state = state.copyWith(isLoadingMorePens: true);
        try {
          final result = await repo.getPens(
            brands: state.penFilter.brands.isNotEmpty ? state.penFilter.brands : null,
            nibSize: state.penFilter.nibSize,
            nibMaterial: state.penFilter.nibMaterial,
            fillTypes: state.penFilter.fillTypes.isNotEmpty ? state.penFilter.fillTypes : null,
            search: state.search.isNotEmpty ? state.search : null,
            lastDoc: state.penLastDoc,
          );
          if (!mounted) return;
          if (gen != _penGen) {
            state = state.copyWith(isLoadingMorePens: false);
            return;
          }
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
          if (!mounted) return;
          state = state.copyWith(isLoadingMorePens: false);
        }
    }
  }

  void setTab(int index) {
    state = state.copyWith(tabIndex: index);
    _load();
  }

  // 새 제품 등록/수정 후 목록만 다시 불러옴 — ref.invalidate로 provider를
  // 통째로 재생성하면 tabIndex/필터/정렬이 기본값(잉크 탭)으로 리셋돼서,
  // 만년필 탭에서 등록했는데도 목록이 안 보이는 문제가 있었음.
  void refresh() => _load();

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
