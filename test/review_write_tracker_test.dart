import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/analytics/analytics_logger.dart';
import 'package:nibpen/features/review/analytics/review_write_tracker.dart';

/// docs/analytics_spec.md의 QA 시나리오를 트래커 단위에서 재현한다.
/// 화면 연결은 실기기 QA로, 이벤트 순서·파라미터 규칙은 여기서 검증한다.

class _FakeLogger implements AnalyticsLogger {
  final events = <({String name, Map<String, Object> params})>[];

  List<String> get names => events.map((e) => e.name).toList();
  Map<String, Object> last(String name) =>
      events.lastWhere((e) => e.name == name).params;

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async =>
      events.add((name: name, params: params));

  @override
  Future<void> setUserProperty(String name, String value) async {}
}

class _Clock {
  var time = DateTime(2026, 10, 13, 12);
  DateTime now() => time;
  void advance(int ms) => time = time.add(Duration(milliseconds: ms));
}

void main() {
  late _FakeLogger logger;
  late _Clock clock;

  ReviewWriteTracker tracker({
    ReviewWriteMode mode = ReviewWriteMode.create,
    ReviewEntryPoint entry = ReviewEntryPoint.reviewFeed,
  }) =>
      ReviewWriteTracker(
        logger: logger,
        mode: mode,
        entryPoint: entry,
        sessionId: 'session-1',
        now: clock.now,
      );

  void attempt(ReviewWriteTracker t, {int photoCount = 0}) => t.attempt(
        photoCount: photoCount,
        titleLength: 5,
        bodyLength: 20,
        inkTagCount: 0,
        penTagCount: 0,
      );

  setUp(() {
    logger = _FakeLogger();
    clock = _Clock();
  });

  test('S1 정상 작성: 퍼널 순서대로 기록되고 공통 파라미터가 모든 이벤트에 붙는다', () {
    final t = tracker()..view();
    clock.advance(1500);
    t.input(ReviewInputKind.title);
    t.input(ReviewInputKind.title); // 타이핑마다 호출돼도 start는 1번
    t.photoAdded(source: ReviewPhotoSource.gallery, addedCount: 2, photoCountAfter: 2);
    attempt(t, photoCount: 2);
    clock.advance(800);
    t.succeeded(reviewId: 'review-1', photoCount: 2);

    expect(logger.names, [
      'review_write_view',
      'review_write_start',
      'review_photo_add',
      'review_submit_attempt',
      'review_submit_success',
    ]);
    for (final e in logger.events) {
      expect(e.params['write_session_id'], 'session-1');
      expect(e.params['mode'], 'new');
      expect(e.params['entry_point'], 'review_feed');
    }
    expect(logger.last('review_write_start')['first_input'], 'title');
    expect(logger.last('review_write_start')['since_view_ms'], 1500);
    expect(logger.last('review_submit_success'), containsPair('review_id', 'review-1'));
    expect(logger.last('review_submit_success')['elapsed_ms'], 800);
  });

  test('S2 사진 없이 등록 → 막힘 → 사진 추가 후 재시도: attempt_no가 이어진다', () {
    final t = tracker(entry: ReviewEntryPoint.home)..view();
    t.input(ReviewInputKind.title);
    attempt(t);
    t.blocked(ReviewBlockReason.noPhoto);
    t.photoAdded(source: ReviewPhotoSource.camera, addedCount: 1, photoCountAfter: 1);
    attempt(t, photoCount: 1);
    t.succeeded(reviewId: 'review-1', photoCount: 1);

    expect(logger.last('review_submit_blocked'),
        allOf(containsPair('reason', 'no_photo'), containsPair('attempt_no', 1)));
    expect(logger.last('review_submit_success')['attempt_no'], 2);
  });

  test('S3 제품 상세 진입 후 바로 이탈: 자동 태깅은 작성 시작이 아니다', () {
    final t = tracker(entry: ReviewEntryPoint.productDetail)
      ..view(prefilledProductType: 'ink');
    t.exited(hadContent: true);

    expect(logger.names, ['review_write_view', 'review_write_exit']);
    expect(logger.last('review_write_view')['prefilled_product_type'], 'ink');
    expect(logger.last('review_write_exit'),
        allOf(containsPair('last_stage', 'view'), containsPair('had_content', 1)));
  });

  test('S4 사진부터 추가: first_input=photo, 삭제 후 사진 수가 맞는다', () {
    final t = tracker()..view();
    t.photoAdded(source: ReviewPhotoSource.camera, addedCount: 1, photoCountAfter: 1);
    t.photoAdded(source: ReviewPhotoSource.gallery, addedCount: 2, photoCountAfter: 3);
    t.photoRemoved(photoCountAfter: 2);
    attempt(t, photoCount: 2);
    t.succeeded(reviewId: 'review-1', photoCount: 2);

    expect(logger.last('review_write_start')['first_input'], 'photo');
    expect(logger.names.where((n) => n == 'review_write_start'), hasLength(1));
    expect(logger.last('review_submit_attempt')['photo_count'],
        logger.last('review_submit_success')['photo_count']);
  });

  test('S5 이탈: 가장 깊이 도달한 단계가 last_stage로 남는다', () {
    final t = tracker()..view();
    t.input(ReviewInputKind.body);
    t.photoAdded(source: ReviewPhotoSource.gallery, addedCount: 1, photoCountAfter: 1);
    t.photoRemoved(photoCountAfter: 0); // 사진을 지워도 도달 단계는 내려가지 않음
    t.exited(hadContent: true);

    expect(logger.last('review_write_exit')['last_stage'], 'photo_added');
  });

  test('업로드 실패: error_stage와 경과 시간이 남고, 재시도 성공 시 세션이 끝난다', () {
    final t = tracker()..view();
    t.photoAdded(source: ReviewPhotoSource.gallery, addedCount: 1, photoCountAfter: 1);
    attempt(t, photoCount: 1);
    clock.advance(3000);
    t.failed(ReviewErrorStage.imageUpload, Exception('network'));
    attempt(t, photoCount: 1);
    t.succeeded(reviewId: 'review-1', photoCount: 1);

    expect(logger.last('review_submit_fail'), allOf(
      containsPair('error_stage', 'image_upload'),
      containsPair('attempt_no', 1),
      containsPair('elapsed_ms', 3000),
    ));
    expect(t.isFinished, isTrue);
  });

  test('불변 조건: 세션이 끝난 뒤에는 어떤 이벤트도 남지 않는다 (success와 exit 공존 금지)', () {
    final t = tracker()..view();
    t.photoAdded(source: ReviewPhotoSource.gallery, addedCount: 1, photoCountAfter: 1);
    attempt(t, photoCount: 1);
    t.succeeded(reviewId: 'review-1', photoCount: 1);
    final count = logger.events.length;

    t.succeeded(reviewId: 'review-1', photoCount: 1);
    t.exited(hadContent: true);
    attempt(t, photoCount: 1);

    expect(logger.events, hasLength(count));
  });

  test('불변 조건: view는 세션당 1번', () {
    tracker()
      ..view()
      ..view();
    expect(logger.names, ['review_write_view']);
  });

  test('수정 모드는 mode=edit로 기록된다', () {
    tracker(mode: ReviewWriteMode.edit, entry: ReviewEntryPoint.reviewDetail).view();
    expect(logger.last('review_write_view'),
        allOf(containsPair('mode', 'edit'), containsPair('entry_point', 'review_detail')));
  });

  test('진입 경로: 명세에 없는 값은 unknown', () {
    expect(ReviewEntryPoint.fromQuery('product_detail'), ReviewEntryPoint.productDetail);
    expect(ReviewEntryPoint.fromQuery(null), ReviewEntryPoint.unknown);
    expect(ReviewEntryPoint.fromQuery('push_banner'), ReviewEntryPoint.unknown);
  });

  test('error_type: Firebase 예외가 아니면 타입명을 쓴다', () {
    expect(ReviewWriteTracker.errorTypeOf(Exception('x')), '_Exception');
    expect(ReviewWriteTracker.errorTypeOf(StateError('x')), 'StateError');
  });
}
