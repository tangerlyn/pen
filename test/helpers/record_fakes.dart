import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/core/analytics/analytics_logger.dart';
import 'package:nibpen/data/models/ink_book_model.dart';
import 'package:nibpen/data/models/ink_chart_model.dart';
import 'package:nibpen/data/models/owned_ink_model.dart';
import 'package:nibpen/data/repositories/ink_book_repository.dart';
import 'package:nibpen/data/repositories/ink_request_repository.dart';
import 'package:nibpen/data/repositories/owned_ink_repository.dart';
import 'package:nibpen/data/services/storage_service.dart';

/// 기록 홈·스와치 기록 테스트용 가짜 구현. Firebase 없이 호출 기록만 남긴다.
/// (Repository들이 FirebaseFirestore.instance를 필드에서 바로 잡기 때문에
/// 상속이 아니라 implements + Fake로 만든다)

class FakeLogger implements AnalyticsLogger {
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

InkBookModel book(String id, {String name = '공책', String visibility = 'public'}) =>
    InkBookModel(
      id: id,
      name: name,
      coverColor: '#2196F3',
      createdAt: DateTime(2026, 1, 1),
      visibility: visibility,
    );

InkChartModel chartEntry(
  String id, {
  String brand = 'Pilot',
  String inkName = 'Kon-peki',
  DateTime? createdAt,
  DateTime? recordedAt,
  String? penName,
  String photoUrl = '',
}) =>
    InkChartModel(
      id: id,
      photoUrl: photoUrl,
      brand: brand,
      inkName: inkName,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      recordedAt: recordedAt,
      penName: penName,
    );

class FakeInkBookRepository extends Fake implements InkBookRepository {
  FakeInkBookRepository({List<InkBookModel>? books, Map<String, List<InkChartModel>>? charts})
      : books = books ?? [],
        charts = charts ?? {};

  final List<InkBookModel> books;
  final Map<String, List<InkChartModel>> charts;
  final created = <({String name, String visibility})>[];
  final added = <({String bookId, InkChartModel entry})>[];
  final updated = <({String bookId, InkChartModel entry})>[];
  Object? addError;

  @override
  Stream<List<InkBookModel>> watchBooks(String uid) => Stream.value(List.of(books));

  @override
  Stream<List<InkChartModel>> watchChart(String uid, String bookId) =>
      Stream.value(charts[bookId] ?? const []);

  @override
  Future<String> createBook(String uid, String name, String coverColor,
      {String visibility = 'public'}) async {
    final id = 'book-${created.length + 1}';
    created.add((name: name, visibility: visibility));
    books.add(book(id, name: name, visibility: visibility));
    return id;
  }

  @override
  Future<void> addEntry(String uid, String bookId, InkChartModel entry) async {
    final error = addError;
    if (error != null) throw error;
    added.add((bookId: bookId, entry: entry));
  }

  @override
  Future<void> updateRecord(String uid, String bookId, InkChartModel entry) async {
    updated.add((bookId: bookId, entry: entry));
  }
}

class FakeStorageService extends Fake implements StorageService {
  final uploaded = <String>[];
  final deleted = <String>[];

  @override
  Future<String> uploadInkChartPhoto(File file, String uid) async {
    final url = 'https://storage/inkChart/$uid/${uploaded.length + 1}.png';
    uploaded.add(url);
    return url;
  }

  @override
  Future<void> deleteByUrl(String url) async => deleted.add(url);
}

class FakeInkRequestRepository extends Fake implements InkRequestRepository {
  final requests = <({String brand, String name})>[];

  @override
  Future<String> create({required String uid, required String brand, required String name}) async {
    requests.add((brand: brand, name: name));
    return 'req-${requests.length}';
  }
}

class FakeOwnedInkRepository extends Fake implements OwnedInkRepository {
  final owned = <String, OwnedInk>{};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<bool> watchIsOwned(String uid, String inkId) async* {
    yield owned.containsKey(inkId);
    await for (final _ in _changes.stream) {
      yield owned.containsKey(inkId);
    }
  }

  @override
  Future<void> add(String uid, OwnedInk ink) async {
    owned[ink.inkId] = ink;
    _changes.add(null);
  }

  @override
  Future<void> remove(String uid, String inkId) async {
    owned.remove(inkId);
    _changes.add(null);
  }
}
