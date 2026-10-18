import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/analytics/analytics_logger.dart';

/// 리뷰 작성 퍼널 로그를 남기는 트래커. 작성 화면 하나(= 작성 세션 하나)당 하나씩 만든다.
/// 이벤트·파라미터 정의는 docs/analytics_spec.md와 1:1로 맞춘다 — 여기를 고치면 명세도 고칠 것.
class ReviewWriteTracker {
  ReviewWriteTracker({
    required AnalyticsLogger logger,
    required this.mode,
    required this.entryPoint,
    String? sessionId,
    DateTime Function()? now,
  })  : _logger = logger,
        _now = now ?? DateTime.now,
        sessionId = sessionId ?? const Uuid().v4();

  final AnalyticsLogger _logger;
  final DateTime Function() _now;

  final String sessionId;
  final ReviewWriteMode mode;
  final ReviewEntryPoint entryPoint;

  DateTime? _viewedAt;
  DateTime? _attemptedAt;
  int _attemptNo = 0;
  ReviewWriteStage _stage = ReviewWriteStage.view;
  bool _viewed = false;
  bool _started = false;
  bool _finished = false; // success 또는 exit가 남으면 세션 종료

  bool get isFinished => _finished;

  /// 화면 진입. 세션당 1회.
  void view({String? prefilledProductType}) {
    if (_viewed) return;
    _viewed = true;
    _viewedAt = _now();
    _log('review_write_view', {
      'prefilled_product_type': prefilledProductType ?? 'none',
    });
  }

  /// 사용자 입력이 생길 때마다 호출해도 되고, 첫 입력에서만 `review_write_start`를 남긴다.
  /// 자동 태깅·수정 모드 초기값처럼 사용자가 하지 않은 변경에는 호출하지 않는다.
  void input(ReviewInputKind kind) {
    if (_started || _finished) return;
    _started = true;
    _advance(ReviewWriteStage.started);
    _log('review_write_start', {
      'first_input': kind.name,
      'since_view_ms': _msSince(_viewedAt),
    });
  }

  void photoAdded({
    required ReviewPhotoSource source,
    required int addedCount,
    required int photoCountAfter,
  }) {
    if (_finished) return;
    input(ReviewInputKind.photo);
    _advance(ReviewWriteStage.photoAdded);
    _log('review_photo_add', {
      'source': source.name,
      'added_count': addedCount,
      'photo_count_after': photoCountAfter,
    });
  }

  void photoRemoved({required int photoCountAfter}) {
    if (_finished) return;
    _log('review_photo_remove', {'photo_count_after': photoCountAfter});
  }

  /// 저장 버튼 탭. 검증보다 먼저 호출한다.
  void attempt({
    required int photoCount,
    required int titleLength,
    required int bodyLength,
    required int inkTagCount,
    required int penTagCount,
  }) {
    if (_finished) return;
    _attemptNo++;
    _attemptedAt = _now();
    _advance(ReviewWriteStage.attempted);
    _log('review_submit_attempt', {
      'attempt_no': _attemptNo,
      'photo_count': photoCount,
      'title_len': titleLength,
      'body_len': bodyLength,
      'ink_tag_count': inkTagCount,
      'pen_tag_count': penTagCount,
    });
  }

  void blocked(ReviewBlockReason reason) {
    if (_finished) return;
    _log('review_submit_blocked', {
      'attempt_no': _attemptNo,
      'reason': reason.wireName,
    });
  }

  void failed(ReviewErrorStage stage, Object error) {
    if (_finished) return;
    _log('review_submit_fail', {
      'attempt_no': _attemptNo,
      'error_stage': stage.wireName,
      'error_type': errorTypeOf(error),
      'elapsed_ms': _msSince(_attemptedAt),
    });
  }

  /// Firestore 쓰기가 끝난 직후 호출. 세션당 1회.
  void succeeded({required String reviewId, required int photoCount}) {
    if (_finished) return;
    _finished = true;
    _log('review_submit_success', {
      'review_id': reviewId,
      'attempt_no': _attemptNo,
      'photo_count': photoCount,
      'elapsed_ms': _msSince(_attemptedAt),
    });
  }

  /// 등록하지 않고 화면을 떠남이 확정된 순간. 세션당 1회.
  void exited({required bool hadContent}) {
    if (_finished) return;
    _finished = true;
    _log('review_write_exit', {
      'last_stage': _stage.wireName,
      'had_content': hadContent ? 1 : 0,
      'since_view_ms': _msSince(_viewedAt),
    });
  }

  void _advance(ReviewWriteStage next) {
    if (next.index > _stage.index) _stage = next;
  }

  int _msSince(DateTime? from) =>
      from == null ? 0 : _now().difference(from).inMilliseconds;

  void _log(String name, Map<String, Object> params) {
    _logger.logEvent(name, {
      'write_session_id': sessionId,
      'mode': mode.wireName,
      'entry_point': entryPoint.wireName,
      ...params,
    });
  }

  /// GA4 문자열 파라미터는 100자 제한. Firebase 예외는 에러 코드를, 나머지는 타입명을 쓴다.
  static String errorTypeOf(Object error) {
    final type = error is FirebaseException
        ? error.code
        : error.runtimeType.toString();
    return type.length > 100 ? type.substring(0, 100) : type;
  }
}

enum ReviewWriteMode {
  create('new'),
  edit('edit');

  const ReviewWriteMode(this.wireName);
  final String wireName;
}

enum ReviewEntryPoint {
  home('home'),
  reviewFeed('review_feed'),
  productDetail('product_detail'),
  reviewDetail('review_detail'),
  unknown('unknown');

  const ReviewEntryPoint(this.wireName);
  final String wireName;

  /// 라우트 쿼리 파라미터 `entry` 값 → 진입 경로. 명세에 없는 값은 unknown.
  static ReviewEntryPoint fromQuery(String? value) => ReviewEntryPoint.values
      .firstWhere((e) => e.wireName == value, orElse: () => unknown);
}

enum ReviewInputKind { title, body, tag, photo }

enum ReviewPhotoSource { camera, gallery }

enum ReviewBlockReason {
  noPhoto('no_photo');

  const ReviewBlockReason(this.wireName);
  final String wireName;
}

enum ReviewErrorStage {
  imageUpload('image_upload'),
  auth('auth'),
  firestoreWrite('firestore_write');

  const ReviewErrorStage(this.wireName);
  final String wireName;
}

enum ReviewWriteStage {
  view('view'),
  started('started'),
  photoAdded('photo_added'),
  attempted('attempted');

  const ReviewWriteStage(this.wireName);
  final String wireName;
}
