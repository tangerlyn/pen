import 'package:shared_preferences/shared_preferences.dart';

enum InkBookSortOption { defaultOrder, brand, color }

enum InkBookPageStyle { lines, grid, plain }

enum InkBookViewMode { pageView, scroll }

extension InkBookSortOptionLabels on InkBookSortOption {
  String get label => switch (this) {
    InkBookSortOption.defaultOrder => '기본순',
    InkBookSortOption.brand => '브랜드순',
    InkBookSortOption.color => '색상순',
  };

  String get description => switch (this) {
    InkBookSortOption.defaultOrder => '추가한 순서대로',
    InkBookSortOption.brand => '브랜드명 가나다순',
    InkBookSortOption.color => '사진의 주요 색상 기준',
  };
}

extension InkBookPageStyleLabels on InkBookPageStyle {
  String get label => switch (this) {
    InkBookPageStyle.lines => '실선',
    InkBookPageStyle.grid => '격자',
    InkBookPageStyle.plain => '민무늬',
  };
}

extension InkBookViewModeLabels on InkBookViewMode {
  String get label => switch (this) {
    InkBookViewMode.pageView => '좌우 스와이프',
    InkBookViewMode.scroll => '위아래 스와이프',
  };

  String get description => switch (this) {
    InkBookViewMode.pageView => '좌우 스와이프, 3×3 페이지',
    InkBookViewMode.scroll => '위아래 스와이프, 3×3 페이지',
  };
}

class InkBookDisplayController {
  InkBookDisplayController(this.bookId);

  final String bookId;
  InkBookSortOption sort = InkBookSortOption.defaultOrder;
  InkBookPageStyle pageStyle = InkBookPageStyle.lines;
  InkBookViewMode viewMode = InkBookViewMode.pageView;

  String get sortKey => 'inkBook_sort_$bookId';
  String get pageStyleKey => 'inkBook_style_$bookId';
  String get viewModeKey => 'inkBook_view_$bookId';

  void load(SharedPreferences preferences) {
    sort = _enumByName(
      InkBookSortOption.values,
      preferences.getString(sortKey),
      InkBookSortOption.defaultOrder,
    );
    pageStyle = _enumByName(
      InkBookPageStyle.values,
      preferences.getString(pageStyleKey),
      InkBookPageStyle.lines,
    );
    viewMode = _enumByName(
      InkBookViewMode.values,
      preferences.getString(viewModeKey),
      InkBookViewMode.pageView,
    );
  }

  Future<void> save(SharedPreferences preferences) async {
    await Future.wait([
      preferences.setString(sortKey, sort.name),
      preferences.setString(pageStyleKey, pageStyle.name),
      preferences.setString(viewModeKey, viewMode.name),
    ]);
  }

  int pageCount(int itemCount, {int itemsPerPage = 9}) {
    if (itemCount <= 0) return 0;
    return (itemCount / itemsPerPage).ceil();
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}
