import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/utils/search_utils.dart';

void main() {
  group('SearchUtils safety contract', () {
    test('query tokens stay unique and within the Firestore limit', () {
      final tokens = SearchUtils.queryTokens('만년필 잉크 종이 노트 필사 기록');

      expect(tokens.length, lessThanOrEqualTo(10));
      expect(tokens.toSet().length, tokens.length);
    });

    test('all query words must occur in the candidate text', () {
      expect(SearchUtils.matchesQuery('파란 만년필 잉크 리뷰', '만년필 잉크'), isTrue);
      expect(SearchUtils.matchesQuery('파란 만년필 리뷰', '만년필 잉크'), isFalse);
    });
  });
}
