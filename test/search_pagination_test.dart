import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/data/models/post_model.dart';
import 'package:nibpen/data/models/review_model.dart';
import 'package:nibpen/data/repositories/search_repository.dart';
import 'package:nibpen/features/search/providers/search_provider.dart';

void main() {
  group('SearchNotifier pagination safety', () {
    test(
      'keeps fetching candidate pages until an exact match is found',
      () async {
        final source = _FakeSearchDataSource(
          reviewPages: [
            SearchPage(
              items: [_review('candidate', title: '파란 잉크')],
              nextCursor: 'candidate',
              hasMore: true,
            ),
            SearchPage(
              items: [_review('match', title: '파란 만년필')],
              nextCursor: 'match',
              hasMore: false,
            ),
          ],
        );
        final notifier = SearchNotifier('review', source);

        await notifier.search('만년필');

        expect(source.reviewCalls, 2);
        expect(notifier.state.reviews.map((item) => item.id), ['match']);
        expect(notifier.state.hasMoreReviews, isFalse);
      },
    );

    test('paginates review and community results independently', () async {
      final source = _FakeSearchDataSource(
        reviewPages: [
          SearchPage(items: [_review('r1')], nextCursor: 'r1', hasMore: true),
          SearchPage(
            items: [_review('r1'), _review('r2', likeCount: 9)],
            nextCursor: 'r2',
            hasMore: false,
          ),
        ],
        postPages: [
          SearchPage(items: [_post('p1')], nextCursor: 'p1', hasMore: true),
          SearchPage(items: [_post('p2')], nextCursor: 'p2', hasMore: false),
        ],
      );
      final notifier = SearchNotifier('all', source);

      await notifier.search('만년필');
      await notifier.loadMoreReviews();

      expect(source.reviewCalls, 2);
      expect(source.postCalls, 1);
      expect(notifier.state.rawReviews.map((item) => item.id), ['r1', 'r2']);
      expect(notifier.state.posts.map((item) => item.id), ['p1']);
      expect(notifier.state.hasMoreReviews, isFalse);
      expect(notifier.state.hasMorePosts, isTrue);

      await notifier.loadMorePosts();
      expect(notifier.state.posts.map((item) => item.id), ['p2', 'p1']);
      expect(notifier.state.hasMorePosts, isFalse);
    });

    test(
      're-sorts the complete aggregate after loading another page',
      () async {
        final source = _FakeSearchDataSource(
          reviewPages: [
            SearchPage(
              items: [_review('r1', likeCount: 1)],
              nextCursor: 'r1',
              hasMore: true,
            ),
            SearchPage(
              items: [_review('r2', likeCount: 99)],
              nextCursor: 'r2',
              hasMore: false,
            ),
          ],
        );
        final notifier = SearchNotifier('review', source);

        await notifier.search('만년필');
        notifier.setReviewSort(ReviewSortOption.popular);
        await notifier.loadMoreReviews();

        expect(notifier.state.reviews.map((item) => item.id), ['r2', 'r1']);
      },
    );

    test('coalesces duplicate load-more requests', () async {
      final source = _FakeSearchDataSource(
        reviewPages: [
          SearchPage(
            items: [_review('r1')],
            nextCursor: 'r1',
            hasMore: true,
          ),
          SearchPage(
            items: [_review('r2')],
            nextCursor: 'r2',
            hasMore: false,
          ),
        ],
      );
      final notifier = SearchNotifier('review', source);
      await notifier.search('만년필');

      final first = notifier.loadMoreReviews();
      final duplicate = notifier.loadMoreReviews();
      await Future.wait([first, duplicate]);

      expect(source.reviewCalls, 2);
      expect(notifier.state.reviews.map((item) => item.id), ['r2', 'r1']);
    });

    test('a newer query wins over an older in-flight query', () async {
      final firstRequest = Completer<SearchPage<ReviewModel>>();
      var calls = 0;
      final source = _CallbackSearchDataSource(
        onReviews: ({required tokens, cursor, required limit}) {
          calls += 1;
          if (calls == 1) return firstRequest.future;
          return Future.value(
            SearchPage(
              items: [_review('new', title: '새 검색')],
              nextCursor: null,
              hasMore: false,
            ),
          );
        },
      );
      final notifier = SearchNotifier('review', source);

      final oldSearch = notifier.search('옛 검색');
      await notifier.search('새 검색');
      firstRequest.complete(
        SearchPage(
          items: [_review('old', title: '옛 검색')],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await oldSearch;

      expect(notifier.state.reviews.map((item) => item.id), ['new']);
    });
  });
}

ReviewModel _review(String id, {String title = '만년필 리뷰', int likeCount = 0}) {
  return ReviewModel(
    id: id,
    authorId: 'author',
    imageUrls: const [],
    title: title,
    likeCount: likeCount,
    createdAt: DateTime.utc(2026, 1, id == 'r2' ? 2 : 1),
  );
}

PostModel _post(String id) {
  return PostModel(
    id: id,
    authorId: 'author',
    authorNickname: '작성자',
    title: '만년필 이야기',
    body: '',
    createdAt: DateTime.utc(2026, 1, id == 'p2' ? 2 : 1),
  );
}

class _FakeSearchDataSource implements SearchRepository {
  _FakeSearchDataSource({
    List<SearchPage<ReviewModel>> reviewPages = const [],
    List<SearchPage<PostModel>> postPages = const [],
  }) : _reviewPages = [...reviewPages],
       _postPages = [...postPages];

  final List<SearchPage<ReviewModel>> _reviewPages;
  final List<SearchPage<PostModel>> _postPages;
  int reviewCalls = 0;
  int postCalls = 0;

  @override
  Future<SearchPage<ReviewModel>> fetchReviews({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) async {
    reviewCalls += 1;
    return _reviewPages.removeAt(0);
  }

  @override
  Future<SearchPage<PostModel>> fetchPosts({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) async {
    postCalls += 1;
    return _postPages.removeAt(0);
  }
}

typedef _ReviewCallback =
    Future<SearchPage<ReviewModel>> Function({
      required List<String> tokens,
      String? cursor,
      required int limit,
    });

class _CallbackSearchDataSource implements SearchRepository {
  const _CallbackSearchDataSource({required this.onReviews});

  final _ReviewCallback onReviews;

  @override
  Future<SearchPage<ReviewModel>> fetchReviews({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) {
    return onReviews(tokens: tokens, cursor: cursor, limit: limit);
  }

  @override
  Future<SearchPage<PostModel>> fetchPosts({
    required List<String> tokens,
    String? cursor,
    required int limit,
  }) {
    throw UnimplementedError();
  }
}
