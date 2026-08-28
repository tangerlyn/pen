import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/features/mypage/controllers/ink_book_display_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'invalid persisted values fall back and keys stay book-scoped',
    () async {
      SharedPreferences.setMockInitialValues({
        'inkBook_sort_book-1': 'unknown',
        'inkBook_style_book-1': 'grid',
        'inkBook_view_book-1': 'scroll',
      });
      final preferences = await SharedPreferences.getInstance();
      final controller = InkBookDisplayController('book-1')..load(preferences);

      expect(controller.sort, InkBookSortOption.defaultOrder);
      expect(controller.pageStyle, InkBookPageStyle.grid);
      expect(controller.viewMode, InkBookViewMode.scroll);
      expect(controller.sortKey, 'inkBook_sort_book-1');
      expect(controller.pageCount(0), 0);
      expect(controller.pageCount(10), 2);
    },
  );

  test('display choices persist together', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = InkBookDisplayController('book-2')
      ..sort = InkBookSortOption.brand
      ..pageStyle = InkBookPageStyle.plain
      ..viewMode = InkBookViewMode.scroll;

    await controller.save(preferences);

    expect(preferences.getString(controller.sortKey), 'brand');
    expect(preferences.getString(controller.pageStyleKey), 'plain');
    expect(preferences.getString(controller.viewModeKey), 'scroll');
  });
}
