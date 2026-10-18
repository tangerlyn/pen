import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/analytics/analytics_logger.dart';

/// 스와치 기록 퍼널 로그를 남기는 트래커. 기록 화면 하나(= 기록 세션 하나)당 하나씩 만든다.
/// 이벤트·파라미터 정의는 docs/analytics_spec_swatch.md와 1:1로 맞춘다 — 여기를 고치면 명세도 고칠 것.
class SwatchRecordTracker {
  SwatchRecordTracker({
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
  final SwatchRecordMode mode;
  final SwatchEntryPoint entryPoint;

  DateTime? _startedAt;
  bool _started = false;
  bool _finished = false; // success 또는 exit가 남으면 세션 종료
  bool _hasPhoto = false;
  bool _hasInk = false;
  bool _saveFailed = false;

  bool get isFinished => _finished;

  /// 화면 진입. 세션당 1회, 모든 이벤트보다 먼저.
  void start({required bool hasPresetInk}) {
    if (_started) return;
    _started = true;
    _startedAt = _now();
    _log('swatch_record_start', {'has_preset_ink': hasPresetInk ? 1 : 0});
  }

  /// 크롭 완료 직후. 크롭에서 취소하면 호출하지 않는다.
  void photoSelected({
    required SwatchPhotoSource source,
    required String cropShape,
    required bool isReplace,
  }) {
    if (_finished) return;
    _hasPhoto = true;
    _log('swatch_photo_select', {
      'source': source.name,
      'crop_shape': cropShape,
      'is_replace': isReplace ? 1 : 0,
    });
  }

  void inkMatched({
    required SwatchMatchType matchType,
    int queryLength = 0,
    int filterCount = 0,
  }) {
    if (_finished) return;
    _hasInk = true;
    _log('swatch_ink_match', {
      'match_type': matchType.wireName,
      'query_len': queryLength,
      'filter_count': filterCount,
    });
  }

  void saveFailed(SwatchErrorStage stage, Object error) {
    if (_finished) return;
    _saveFailed = true;
    _log('swatch_save_fail', {
      'error_stage': stage.wireName,
      'error_type': errorTypeOf(error),
    });
  }

  /// Firestore 쓰기가 끝난 직후 호출. 세션당 1회.
  void saved({
    required String recordId,
    required bool hasInkId,
    required int optionalFieldCount,
    required bool createdBook,
  }) {
    if (_finished) return;
    _finished = true;
    _log('swatch_save_success', {
      'record_id': recordId,
      'has_ink_id': hasInkId ? 1 : 0,
      'optional_field_count': optionalFieldCount,
      'created_book': createdBook ? 1 : 0,
      'elapsed_ms': _msSince(_startedAt),
    });
  }

  /// 저장하지 않고 화면을 떠남이 확정된 순간. 세션당 1회.
  void exited({required bool hadContent}) {
    if (_finished) return;
    _finished = true;
    _log('swatch_record_exit', {
      'last_stage': lastStage.wireName,
      'had_content': hadContent ? 1 : 0,
      'since_start_ms': _msSince(_startedAt),
    });
  }

  /// 필수 입력(사진·잉크) 기준의 진행도. 잉크만 있고 사진이 없으면 아직 start.
  SwatchRecordStage get lastStage {
    if (_saveFailed) return SwatchRecordStage.saveFailed;
    if (_hasPhoto && _hasInk) return SwatchRecordStage.inkMatched;
    if (_hasPhoto) return SwatchRecordStage.photoSelected;
    return SwatchRecordStage.start;
  }

  int _msSince(DateTime? from) =>
      from == null ? 0 : _now().difference(from).inMilliseconds;

  void _log(String name, Map<String, Object> params) {
    _logger.logEvent(name, {
      'record_session_id': sessionId,
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

enum SwatchRecordMode {
  create('new'),
  edit('edit');

  const SwatchRecordMode(this.wireName);
  final String wireName;
}

enum SwatchEntryPoint {
  home('home'),
  emptyState('empty_state'),
  inkDetail('ink_detail'),
  recordDetail('record_detail'),
  unknown('unknown');

  const SwatchEntryPoint(this.wireName);
  final String wireName;

  /// 라우트 쿼리 파라미터 `entry` 값 → 진입 경로. 명세에 없는 값은 unknown.
  static SwatchEntryPoint fromQuery(String? value) => SwatchEntryPoint.values
      .firstWhere((e) => e.wireName == value, orElse: () => unknown);
}

enum SwatchPhotoSource { camera, gallery }

enum SwatchMatchType {
  archive('archive'),
  preset('preset'),
  request('request'),
  freeText('free_text');

  const SwatchMatchType(this.wireName);
  final String wireName;
}

enum SwatchErrorStage {
  photoUpload('photo_upload'),
  bookCreate('book_create'),
  firestoreWrite('firestore_write');

  const SwatchErrorStage(this.wireName);
  final String wireName;
}

enum SwatchRecordStage {
  start('start'),
  photoSelected('photo_selected'),
  inkMatched('ink_matched'),
  saveFailed('save_failed');

  const SwatchRecordStage(this.wireName);
  final String wireName;
}
