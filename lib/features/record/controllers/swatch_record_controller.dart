import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/analytics/analytics_logger.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/providers/owned_ink_providers.dart';
import '../../../shared/providers/providers.dart';
import '../analytics/swatch_record_tracker.dart';

/// 공책이 하나도 없을 때 첫 저장에서 만드는 기본 공책
const kDefaultRecordBookName = '내 잉크 기록';
const kDefaultRecordBookColor = '#2196F3';
const kDefaultRecordBookVisibility = 'private';

const _kLastRecordBookKey = 'last_record_book_id';

/// 마지막으로 기록을 저장한 공책 — 다음 기록의 기본 공책
final lastRecordBookIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kLastRecordBookKey);
});

/// 저장할 공책 기본값: 마지막으로 쓴 공책 → 첫 공책 → 없으면 null(저장 시 새로 만듦)
String? resolveDefaultBookId(List<InkBookModel> books, String? lastUsedId) {
  if (books.isEmpty) return null;
  if (lastUsedId != null && books.any((b) => b.id == lastUsedId)) {
    return lastUsedId;
  }
  return books.first.id;
}

/// 기록에 연결할 잉크. 아카이브에서 고르면 inkId가 있고, 직접 입력·요청이면 null.
class SwatchInk {
  const SwatchInk({this.inkId, this.brand = '', required this.name, this.hexColor = ''});

  factory SwatchInk.fromArchive(InkModel ink) => SwatchInk(
        inkId: ink.id,
        brand: ink.brand,
        name: ink.name,
        hexColor: ink.hexColor,
      );

  final String? inkId;
  final String brand;
  final String name;
  final String hexColor;
}

/// 화면 하나당 하나. 화면 State에서 한 번 만들어 들고 있어야 같은 컨트롤러를 쓴다
/// (family 키가 인스턴스 동일성이라 build마다 새로 만들면 세션이 갈라짐).
class SwatchRecordArgs {
  const SwatchRecordArgs({
    required this.entryPoint,
    this.presetInkId,
    this.editBookId,
    this.editEntry,
  });

  final SwatchEntryPoint entryPoint;
  final String? presetInkId;
  final String? editBookId;
  final InkChartModel? editEntry;

  bool get isEdit => editEntry != null;
}

class SwatchRecordState {
  const SwatchRecordState({
    this.photo,
    this.existingPhotoUrl,
    this.ink,
    this.penName = '',
    this.nibSize = '',
    this.paperName = '',
    this.recordedAt,
    this.bookId,
    this.isSaving = false,
  });

  factory SwatchRecordState.fromEntry(InkChartModel? entry) {
    if (entry == null) return const SwatchRecordState();
    return SwatchRecordState(
      existingPhotoUrl: entry.photoUrl.isEmpty ? null : entry.photoUrl,
      ink: SwatchInk(inkId: entry.inkId, brand: entry.brand, name: entry.inkName),
      penName: entry.penName ?? '',
      nibSize: entry.nibSize ?? '',
      paperName: entry.paperName ?? '',
      recordedAt: entry.recordedAt,
    );
  }

  final File? photo;
  final String? existingPhotoUrl;
  final SwatchInk? ink;
  final String penName;
  final String nibSize;
  final String paperName;
  final DateTime? recordedAt;
  /// 사용자가 직접 고른 공책. null이면 resolveDefaultBookId 결과를 쓴다.
  final String? bookId;
  final bool isSaving;

  bool get hasPhoto => photo != null || existingPhotoUrl != null;
  bool get hasInk => (ink?.name.trim() ?? '').isNotEmpty;

  /// 필수 입력은 사진과 잉크 이름뿐
  bool get canSave => hasPhoto && hasInk && !isSaving;

  bool get hasOptionalInput =>
      penName.trim().isNotEmpty ||
      nibSize.trim().isNotEmpty ||
      paperName.trim().isNotEmpty ||
      recordedAt != null;

  SwatchRecordState copyWith({
    File? photo,
    SwatchInk? ink,
    String? penName,
    String? nibSize,
    String? paperName,
    DateTime? recordedAt,
    bool clearRecordedAt = false,
    String? bookId,
    bool? isSaving,
  }) =>
      SwatchRecordState(
        photo: photo ?? this.photo,
        existingPhotoUrl: existingPhotoUrl,
        ink: ink ?? this.ink,
        penName: penName ?? this.penName,
        nibSize: nibSize ?? this.nibSize,
        paperName: paperName ?? this.paperName,
        recordedAt: clearRecordedAt ? null : (recordedAt ?? this.recordedAt),
        bookId: bookId ?? this.bookId,
        isSaving: isSaving ?? this.isSaving,
      );
}

class SwatchSaveResult {
  const SwatchSaveResult({
    required this.bookId,
    required this.entry,
    required this.createdBook,
  });

  final String bookId;
  final InkChartModel entry;
  final bool createdBook;
}

final swatchRecordControllerProvider = StateNotifierProvider.autoDispose
    .family<SwatchRecordController, SwatchRecordState, SwatchRecordArgs>(
  (ref, args) => SwatchRecordController(ref, args),
);

class SwatchRecordController extends StateNotifier<SwatchRecordState> {
  SwatchRecordController(this._ref, this.args)
      : tracker = SwatchRecordTracker(
          logger: _ref.read(analyticsLoggerProvider),
          mode: args.isEdit ? SwatchRecordMode.edit : SwatchRecordMode.create,
          entryPoint: args.entryPoint,
        ),
        // 문서 ID를 화면 진입 시 고정 — 응답만 실패해 다시 저장해도 같은 문서를 덮어씀 (중복 방지)
        _recordId = args.editEntry?.id ?? const Uuid().v4(),
        super(SwatchRecordState.fromEntry(args.editEntry)) {
    tracker.start(hasPresetInk: args.presetInkId != null);
  }

  final Ref _ref;
  final SwatchRecordArgs args;
  final SwatchRecordTracker tracker;
  final String _recordId;

  // ── 입력 ─────────────────────────────────────────────────────────
  /// 잉크 상세에서 들어온 경우. 사용자가 이미 다른 잉크를 골랐으면 덮어쓰지 않는다.
  void applyPresetInk(InkModel ink) {
    if (state.hasInk) return;
    state = state.copyWith(ink: SwatchInk.fromArchive(ink));
    tracker.inkMatched(matchType: SwatchMatchType.preset);
  }

  void setPhoto(File photo, {required SwatchPhotoSource source, required String cropShape}) {
    final isReplace = state.hasPhoto;
    state = state.copyWith(photo: photo);
    tracker.photoSelected(source: source, cropShape: cropShape, isReplace: isReplace);
  }

  void selectInk(
    SwatchInk ink, {
    required SwatchMatchType matchType,
    int queryLength = 0,
    int filterCount = 0,
  }) {
    state = state.copyWith(ink: ink);
    tracker.inkMatched(
      matchType: matchType,
      queryLength: queryLength,
      filterCount: filterCount,
    );
  }

  /// 아카이브에 없는 잉크 — 등록 요청을 남기고 그 이름으로 기록한다.
  Future<void> requestNewInk({
    required String brand,
    required String name,
    int queryLength = 0,
    int filterCount = 0,
  }) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref
        .read(inkRequestRepoProvider)
        .create(uid: uid, brand: brand.trim(), name: name.trim());
    selectInk(
      SwatchInk(brand: brand.trim(), name: name.trim()),
      matchType: SwatchMatchType.request,
      queryLength: queryLength,
      filterCount: filterCount,
    );
  }

  void setPenName(String v) => state = state.copyWith(penName: v);
  void setNibSize(String v) => state = state.copyWith(nibSize: v);
  void setPaperName(String v) => state = state.copyWith(paperName: v);
  void setRecordedAt(DateTime? v) => state = v == null
      ? state.copyWith(clearRecordedAt: true)
      : state.copyWith(recordedAt: v);
  void setBook(String bookId) => state = state.copyWith(bookId: bookId);

  void exit({required bool hadContent}) => tracker.exited(hadContent: hadContent);

  // ── 저장 ─────────────────────────────────────────────────────────
  /// [buildMemoBlocks]는 메모 에디터의 블록(본문 사진 업로드 포함)을 만든다.
  /// 실패하면 swatch_save_fail을 남기고 예외를 다시 던진다 (화면이 안내).
  Future<SwatchSaveResult?> save({
    required Future<List<Map<String, dynamic>>> Function(String uid) buildMemoBlocks,
  }) async {
    if (!state.canSave) return null;
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return null;

    final current = state;
    state = state.copyWith(isSaving: true);
    var stage = SwatchErrorStage.photoUpload;
    String? uploadedUrl;
    try {
      final storage = _ref.read(storageServiceProvider);
      if (current.photo != null) {
        uploadedUrl = await storage.uploadInkChartPhoto(current.photo!, uid);
      }
      final photoUrl = uploadedUrl ?? current.existingPhotoUrl!;
      final memoBlocks = await buildMemoBlocks(uid);
      final memoText = memoBlocks
          .where((b) => b['type'] == 'text')
          .map((b) => b['content'] as String)
          .join('\n');

      stage = SwatchErrorStage.bookCreate;
      final (bookId, createdBook) = args.isEdit
          ? (args.editBookId!, false)
          : await _resolveBook(uid, current.bookId);

      stage = SwatchErrorStage.firestoreWrite;
      final ink = current.ink!;
      final entry = InkChartModel(
        id: _recordId,
        photoUrl: photoUrl,
        brand: ink.brand.trim(),
        inkName: ink.name.trim(),
        memo: memoText,
        contentBlocks: memoBlocks.isNotEmpty ? memoBlocks : null,
        createdAt: args.editEntry?.createdAt ?? DateTime.now(),
        order: args.editEntry?.order ?? 0,
        inkId: ink.inkId,
        penName: _orNull(current.penName),
        nibSize: _orNull(current.nibSize),
        paperName: _orNull(current.paperName),
        recordedAt: current.recordedAt,
      );
      final repo = _ref.read(inkBookRepoProvider);
      if (args.isEdit) {
        await repo.updateRecord(uid, bookId, entry);
      } else {
        await repo.addEntry(uid, bookId, entry);
      }

      tracker.saved(
        recordId: entry.id,
        hasInkId: entry.inkId != null,
        optionalFieldCount: _optionalFieldCount(entry),
        createdBook: createdBook,
      );

      if (!args.isEdit) await _rememberBook(bookId);
      // 사진을 바꿨으면 예전 파일 정리 (실패해도 저장은 성공)
      final oldUrl = current.existingPhotoUrl;
      if (uploadedUrl != null && oldUrl != null && oldUrl != uploadedUrl) {
        await storage.deleteByUrl(oldUrl);
      }
      if (mounted) state = state.copyWith(isSaving: false);
      return SwatchSaveResult(bookId: bookId, entry: entry, createdBook: createdBook);
    } catch (e) {
      tracker.saveFailed(stage, e);
      // 문서가 안 써졌는데 올린 사진은 남지 않게 (다시 저장하면 새로 올림)
      if (uploadedUrl != null) {
        await _ref.read(storageServiceProvider).deleteByUrl(uploadedUrl);
      }
      if (mounted) state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<(String, bool)> _resolveBook(String uid, String? picked) async {
    if (picked != null) return (picked, false);
    final repo = _ref.read(inkBookRepoProvider);
    final books = await repo.watchBooks(uid).first;
    final lastUsed = await _ref.read(lastRecordBookIdProvider.future);
    final existing = resolveDefaultBookId(books, lastUsed);
    if (existing != null) return (existing, false);
    final created = await repo.createBook(
      uid,
      kDefaultRecordBookName,
      kDefaultRecordBookColor,
      visibility: kDefaultRecordBookVisibility,
    );
    return (created, true);
  }

  Future<void> _rememberBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastRecordBookKey, bookId);
    _ref.invalidate(lastRecordBookIdProvider);
  }

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();

  static int _optionalFieldCount(InkChartModel e) => [
        e.brand.isNotEmpty,
        e.penName != null,
        e.nibSize != null,
        e.paperName != null,
        e.memo.trim().isNotEmpty ||
            (e.contentBlocks?.any((b) => b['type'] == 'image') ?? false),
        e.recordedAt != null,
      ].where((filled) => filled).length;
}
