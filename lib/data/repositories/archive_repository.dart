import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/ink_model.dart';
import '../models/pen_model.dart';
import 'review_repository.dart';
import '../../core/constants/app_constants.dart';

class ArchiveRepository {
  ArchiveRepository(this._reviewRepo);
  final ReviewRepository _reviewRepo;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
  );

  CollectionReference get _inks => _firestore.collection(AppConstants.inksCol);
  CollectionReference get _pens => _firestore.collection(AppConstants.pensCol);

  // ── 잉크 ───────────────────────────────────────────────────
  Future<({List<InkModel> items, DocumentSnapshot? lastDoc, bool hasMore})>
  getInks({
    List<String>? brands,
    List<String>? colorFamilies,
    List<String>? inkTypes,
    String? capacityRange,
    String? search,
    DocumentSnapshot? lastDoc,
    int pageSize = 40,
  }) async {
    Query query = _inks;
    if (inkTypes != null && inkTypes.isNotEmpty) {
      query = query.where('inkType', whereIn: inkTypes);
    }
    // search/brands/colorFamilies는 Firestore where절이 아니라 아래에서
    // 클라이언트 쪽으로 필터링한다 — 그 필터들이 있으면 컬렉션 전체를 가져와야
    // 검색어와 일치하는 잉크가 뒤쪽에 있어도 놓치지 않는다. 그런 필터가 없을
    // 때만(=단순 목록 조회) 커서 기반 페이지네이션을 적용한다 — 정렬은
    // ArchiveNotifier가 누적된 전체 목록을 매번 다시 정렬하는 방식이라(클라이언트
    // 정렬), 여기서는 안정적인 순회 순서만 보장하면 되므로 문서 ID로 정렬한다.
    final hasClientFilter =
        (search != null && search.isNotEmpty) ||
        (brands != null && brands.isNotEmpty) ||
        (colorFamilies != null && colorFamilies.isNotEmpty);
    if (!hasClientFilter) {
      query = query.orderBy(FieldPath.documentId).limit(pageSize + 1);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    final snapshot = await query.get();
    var docs = snapshot.docs;
    DocumentSnapshot? nextCursor;
    var hasMore = false;
    if (!hasClientFilter) {
      hasMore = docs.length > pageSize;
      if (hasMore) docs = docs.sublist(0, pageSize);
      nextCursor = docs.isNotEmpty ? docs.last : null;
    }

    var results = docs
        .map(
          (doc) => InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .where((i) => i.brand.isNotEmpty && i.name.isNotEmpty)
        .toList();

    if (brands != null && brands.isNotEmpty) {
      results = results.where((i) => brands.contains(i.brand)).toList();
    }

    if (colorFamilies != null && colorFamilies.isNotEmpty) {
      results = results
          .where((i) => colorFamilies.contains(i.autoColorFamily))
          .toList();
    }

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      results = results
          .where(
            (i) =>
                i.brand.toLowerCase().contains(lower) ||
                i.name.toLowerCase().contains(lower) ||
                i.nameEn.toLowerCase().contains(lower),
          )
          .toList();
    }

    results = await Future.wait(
      results.map((i) async {
        final stats = await _reviewRepo.getProductStats('ink', i.id);
        return i.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
      }),
    );

    return (items: results, lastDoc: nextCursor, hasMore: hasMore);
  }

  /// 리뷰 통계 없이 잉크 기본 정보만 (홈 "최근 본" 목록처럼 여러 개를 띄울 때).
  Future<InkModel?> getInkBasic(String inkId) async {
    final doc = await _inks.doc(inkId).get();
    if (!doc.exists) return null;
    return InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<InkModel?> getInk(String inkId) async {
    final doc = await _inks.doc(inkId).get();
    if (!doc.exists) return null;
    final model = InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final stats = await _reviewRepo.getProductStats('ink', inkId);
    return model.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
  }

  Future<List<InkModel>> searchInks(String query) async {
    final snapshot = await _inks.get();
    final lower = query.toLowerCase();
    return snapshot.docs
        .map(
          (doc) => InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .where(
          (i) =>
              i.brand.toLowerCase().contains(lower) ||
              i.name.toLowerCase().contains(lower) ||
              i.nameEn.toLowerCase().contains(lower),
        )
        .toList();
  }

  // 중복 등록 판정용 정규화 — 앞뒤 공백·연속 공백·대소문자 차이는 같은 제품으로 본다
  static String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  // 같은 브랜드+이름 문서가 있는지 — Firestore는 대소문자 무시 비교가 안 돼서
  // (PILOT vs Pilot) 컬렉션을 받아 클라이언트에서 정규화 비교한다.
  // 검색(searchInks/searchPens)과 같은 방식이고, 등록 시에만 호출된다.
  Future<bool> _productExists(
    CollectionReference col,
    String nameField,
    String brand,
    String name,
  ) async {
    final b = _normalize(brand);
    final n = _normalize(name);
    final snap = await col.get();
    return snap.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _normalize(data['brand'] as String? ?? '') == b &&
          _normalize(data[nameField] as String? ?? '') == n;
    });
  }

  // 동일 브랜드+이름 잉크 존재 여부 확인
  Future<bool> inkExists(String brand, String name) =>
      _productExists(_inks, 'name', brand, name);

  // 동일 브랜드+모델명 만년필 존재 여부 확인
  Future<bool> penExists(String brand, String modelName) =>
      _productExists(_pens, 'modelName', brand, modelName);

  // 잉크 등록 자동완성용 — 기존 브랜드/이름 목록 반환
  Future<({List<String> brands, List<String> names})>
  getInkFieldSuggestions() async {
    final snap = await _inks.limit(800).get();
    final brands = <String>{};
    final names = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final b = data['brand'] as String? ?? '';
      final n = data['name'] as String? ?? '';
      if (b.isNotEmpty) brands.add(b);
      if (n.isNotEmpty) names.add(n);
    }
    return (brands: (brands.toList()..sort()), names: (names.toList()..sort()));
  }

  // 만년필 브랜드 필터용 — 현재 등록된 만년필들의 브랜드 목록(중복 제거)
  Future<List<String>> getPenBrands() async {
    final snap = await _pens.limit(500).get();
    final brands = <String>{};
    for (final doc in snap.docs) {
      final b = (doc.data() as Map<String, dynamic>)['brand'] as String? ?? '';
      if (b.isNotEmpty) brands.add(b);
    }
    return brands.toList();
  }

  // ── 만년필 ──────────────────────────────────────────────────
  Future<({List<PenModel> items, DocumentSnapshot? lastDoc, bool hasMore})>
  getPens({
    List<String>? brands,
    String? nibSize,
    String? nibMaterial,
    List<String>? fillTypes,
    String? search,
    DocumentSnapshot? lastDoc,
    int pageSize = 40,
  }) async {
    Query query = _pens;
    if (nibMaterial != null)
      query = query.where('nibMaterial', isEqualTo: nibMaterial);
    if (nibSize != null)
      query = query.where('nibSizes', arrayContains: nibSize);

    // search/brands/fillTypes는 클라이언트 쪽 필터라, 있으면 컬렉션 전체를
    // 가져와야 조건과 일치하는 만년필을 놓치지 않는다 (getInks와 동일한 이유).
    // 필터가 없을 때만 커서 기반 페이지네이션 적용.
    final hasClientFilter =
        (search != null && search.isNotEmpty) ||
        (brands != null && brands.isNotEmpty) ||
        (fillTypes != null && fillTypes.isNotEmpty);
    if (!hasClientFilter) {
      query = query.orderBy(FieldPath.documentId).limit(pageSize + 1);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
    }
    final snapshot = await query.get();
    var docs = snapshot.docs;
    DocumentSnapshot? nextCursor;
    var hasMore = false;
    if (!hasClientFilter) {
      hasMore = docs.length > pageSize;
      if (hasMore) docs = docs.sublist(0, pageSize);
      nextCursor = docs.isNotEmpty ? docs.last : null;
    }

    var results = docs
        .map(
          (doc) => PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .where((p) => p.brand.isNotEmpty && p.modelName.isNotEmpty)
        .toList();

    if (brands != null && brands.isNotEmpty) {
      results = results.where((p) => brands.contains(p.brand)).toList();
    }

    if (fillTypes != null && fillTypes.isNotEmpty) {
      results = results.where((p) => fillTypes.contains(p.fillType)).toList();
    }

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      results = results
          .where(
            (p) =>
                p.brand.toLowerCase().contains(lower) ||
                p.modelName.toLowerCase().contains(lower),
          )
          .toList();
    }

    results = await Future.wait(
      results.map((p) async {
        final stats = await _reviewRepo.getProductStats('pen', p.id);
        return p.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
      }),
    );

    return (items: results, lastDoc: nextCursor, hasMore: hasMore);
  }

  /// 리뷰 통계 없이 만년필 기본 정보만.
  Future<PenModel?> getPenBasic(String penId) async {
    final doc = await _pens.doc(penId).get();
    if (!doc.exists) return null;
    return PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<PenModel?> getPen(String penId) async {
    final doc = await _pens.doc(penId).get();
    if (!doc.exists) return null;
    final model = PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final stats = await _reviewRepo.getProductStats('pen', penId);
    return model.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
  }

  Future<List<PenModel>> searchPens(String query) async {
    final snapshot = await _pens.get();
    final lower = query.toLowerCase();
    return snapshot.docs
        .map(
          (doc) => PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .where(
          (p) =>
              p.brand.toLowerCase().contains(lower) ||
              p.modelName.toLowerCase().contains(lower),
        )
        .toList();
  }

  // ── 사용자 직접 등록 ─────────────────────────────────────────
  Future<String> addInk({
    required String uid,
    required String brand,
    required String name,
    required String colorFamily,
    required String inkType,
    String hexColor = '#000000',
    int? capacityMl,
  }) async {
    final doc = _inks.doc();
    await doc.set({
      'brand': brand,
      'name': name,
      'colorFamily': colorFamily,
      'inkType': inkType,
      'hexColor': hexColor,
      'capacityMl': capacityMl ?? 0,
      'addedBy': uid,
      'isUserAdded': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateInk({
    required String inkId,
    required String brand,
    required String name,
    required String inkType,
    required String hexColor,
  }) async {
    await _inks.doc(inkId).update({
      'brand': brand,
      'name': name,
      'inkType': inkType,
      'hexColor': hexColor,
    });
  }

  Future<String> addPen({
    required String uid,
    required String brand,
    required String modelName,
    required String fillType,
    String nibMaterial = '스틸닙',
    List<String> nibSizes = const [],
    String lineup = '',
    String priceRange = '',
    String? photoUrl,
  }) async {
    final doc = _pens.doc();
    await doc.set({
      'brand': brand,
      'modelName': modelName,
      'nibMaterial': nibMaterial,
      'nibSizes': nibSizes,
      'fillType': fillType,
      'lineup': lineup,
      'priceRange': priceRange,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'addedBy': uid,
      'isUserAdded': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── 제품 신고 ────────────────────────────────────────────────────
  Future<bool> hasReportedProduct({
    required String targetType,
    required String targetId,
    required String reporterId,
  }) async {
    final reportId = '${targetType}_${targetId}_$reporterId';
    final doc = await _firestore
        .collection(AppConstants.reportsCol)
        .doc(reportId)
        .get();
    return doc.exists;
  }

  Future<void> reportProduct({
    required String targetType,
    required String targetId,
    required String targetName,
    required String reporterId,
    required String reason,
    String detail = '',
  }) async {
    // 문서 ID를 결정적으로 고정 — user_repository.report()와 동일한 이유로
    // 같은 유저의 반복 신고가 새 문서로 쌓이지 않게 덮어쓴다.
    final reportId = '${targetType}_${targetId}_$reporterId';
    await _firestore.collection(AppConstants.reportsCol).doc(reportId).set({
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'reporterId': reporterId,
      'reason': reason,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── 궁합 추천 ────────────────────────────────────────────────────
  Future<List<InkModel>> getTopInksForPen(String penId, {int topN = 3}) async {
    final (reviews, _) = await _reviewRepo.getFeed(penId: penId, limit: 100);
    final counts = <String, int>{};
    for (final r in reviews) {
      for (final iid in r.inkIds) {
        counts[iid] = (counts[iid] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return [];
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted.take(topN).map((e) => e.key).toList();
    final inks = await Future.wait(ids.map(getInk));
    return inks.whereType<InkModel>().toList();
  }
}
