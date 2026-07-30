import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/ink_model.dart';
import '../models/pen_model.dart';
import 'review_repository.dart';
import '../../core/constants/app_constants.dart';

class ArchiveRepository {
  ArchiveRepository(this._reviewRepo) {
    debugPrint('ArchiveRepo Constructor - Firestore app name: ${_firestore.app.name}');
    debugPrint('ArchiveRepo Constructor - Firestore project ID: ${_firestore.app.options.projectId}');
  }
  final ReviewRepository _reviewRepo;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app());

  CollectionReference get _inks => _firestore.collection(AppConstants.inksCol);
  CollectionReference get _pens => _firestore.collection(AppConstants.pensCol);

  // ── CSV 초기화 ────────────────────────────────────────────────
  Future<void> initializeDatabase() async {
    try {
      // 1. Inks — 기존 문서 전체 삭제 후 새로 업로드
      final existingInkDocs = await _inks.get();
      final deleteInkBatch = _firestore.batch();
      for (final doc in existingInkDocs.docs) {
        deleteInkBatch.delete(doc.reference);
      }
      await deleteInkBatch.commit();
      debugPrint('기존 잉크 ${existingInkDocs.docs.length}개 삭제 완료');

      var batch = _firestore.batch();
    final inksCsv = await rootBundle.loadString('assets/info_csv/inks.csv');
    final normalizedCsv = inksCsv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final inksRows = const CsvToListConverter(eol: '\n').convert(normalizedCsv);
    debugPrint('Inks CSV rows: ${inksRows.length}개');
    if (inksRows.isNotEmpty) {
      final headers = inksRows[0].map((e) => e.toString().replaceAll(RegExp(r'^\xEF\xBB\xBF'), '').trim()).toList();
      final idIdx = headers.indexOf('id');
      final brandIdx = headers.indexOf('brand');
      final nameIdx = headers.indexOf('name');
      final inkTypeIdx = headers.indexOf('inkType');
      final hexColorIdx = headers.indexOf('hexColor');
      final capacityIdx = headers.indexOf('capacityMl');

      for (var i = 1; i < inksRows.length; i++) {
        final row = inksRows[i];
        if (row.isEmpty || idIdx == -1 || row.length <= idIdx) continue;
        final id = row[idIdx].toString().trim();
        if (id.isEmpty || id == 'id') continue;

        final data = <String, dynamic>{};
        if (brandIdx != -1 && row.length > brandIdx) data['brand'] = row[brandIdx].toString().trim();
        if (nameIdx != -1 && row.length > nameIdx) data['name'] = row[nameIdx].toString().trim();
        if (inkTypeIdx != -1 && row.length > inkTypeIdx) data['inkType'] = row[inkTypeIdx].toString().trim();
        if (hexColorIdx != -1 && row.length > hexColorIdx) data['hexColor'] = row[hexColorIdx].toString().trim();
        if (capacityIdx != -1 && row.length > capacityIdx) data['capacityMl'] = int.tryParse(row[capacityIdx].toString().trim()) ?? 0;

        batch.set(_inks.doc(id), data);
      }
      await batch.commit();
      debugPrint('Inks batch commit success');
      final testSnap = await _inks.get();
      debugPrint('Inks uploaded: ${testSnap.docs.length}개');
    }

    // 2. Pens
    var batchPens = _firestore.batch();
    final pensCsv = await rootBundle.loadString('assets/info_csv/pens.csv');
    final pensRows = const CsvToListConverter().convert(pensCsv);
    if (pensRows.isNotEmpty) {
      final headers = pensRows[0].map((e) => e.toString().replaceAll(RegExp(r'^\xEF\xBB\xBF'), '').trim()).toList();
      debugPrint('Pens CSV Headers: $headers');
      final idIdx = headers.indexOf('id');
      final brandIdx = headers.indexOf('brand');
      final modelNameIdx = headers.indexOf('modelName');
      final nibMaterialIdx = headers.indexOf('nibMaterial');
      final nibSizesIdx = headers.indexOf('nibSizes');
      final fillTypeIdx = headers.indexOf('fillType');
      final lineupIdx = headers.indexOf('lineup');
      final priceRangeIdx = headers.indexOf('priceRange');

      for (var i = 1; i < pensRows.length; i++) {
        final row = pensRows[i];
        if (row.isEmpty || idIdx == -1 || row.length <= idIdx) continue;
        final id = row[idIdx].toString().trim();
        if (id.isEmpty || id == 'id') continue;

        final data = <String, dynamic>{
          'lineup': lineupIdx != -1 && row.length > lineupIdx ? row[lineupIdx].toString().trim() : '',
        };
        if (brandIdx != -1 && row.length > brandIdx) data['brand'] = row[brandIdx].toString().trim();
        if (modelNameIdx != -1 && row.length > modelNameIdx) data['modelName'] = row[modelNameIdx].toString().trim();
        if (nibMaterialIdx != -1 && row.length > nibMaterialIdx) data['nibMaterial'] = row[nibMaterialIdx].toString().trim();
        if (nibSizesIdx != -1 && row.length > nibSizesIdx) {
          final sizesStr = row[nibSizesIdx].toString().trim();
          data['nibSizes'] = sizesStr.isEmpty ? [] : sizesStr.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        if (fillTypeIdx != -1 && row.length > fillTypeIdx) data['fillType'] = row[fillTypeIdx].toString().trim();
        if (priceRangeIdx != -1 && row.length > priceRangeIdx) data['priceRange'] = row[priceRangeIdx].toString().trim();

        batchPens.set(_pens.doc(id), data, SetOptions(merge: true));
      }
      debugPrint('Before Pens batch commit - Firestore app name: ${_firestore.app.name}');
      debugPrint('Before Pens batch commit - Firestore project ID: ${_firestore.app.options.projectId}');
      await batchPens.commit();
      debugPrint('Pens batch commit success');
    }

    // -- 테스트: DB 쓰기 직후 정상적으로 저장되었는지 확인
    final testSnapshot = await _pens.get();
    debugPrint('Test query after init: pens collection size = ${testSnapshot.docs.length}');

    } catch (e, st) {
      debugPrint('batch commit error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ── 잉크 ───────────────────────────────────────────────────
  Future<List<InkModel>> getInks({
    List<String>? brands,
    List<String>? colorFamilies,
    List<String>? inkTypes,
    String? capacityRange,
    String? search,
    Object? lastDoc,
    int limit = 200,
  }) async {
    Query query = _inks;
    if (inkTypes != null && inkTypes.isNotEmpty) {
      query = query.where('inkType', whereIn: inkTypes);
    }
    query = query.limit(limit);

    final snapshot = await query.get();
    var results = snapshot.docs
        .map((doc) => InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((i) => i.brand.isNotEmpty && i.name.isNotEmpty)
        .toList();

    if (brands != null && brands.isNotEmpty) {
      results = results.where((i) => brands.contains(i.brand)).toList();
    }

    if (colorFamilies != null && colorFamilies.isNotEmpty) {
      results = results.where((i) => colorFamilies.contains(i.autoColorFamily)).toList();
    }

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      results = results.where((i) =>
          i.brand.toLowerCase().contains(lower) ||
          i.name.toLowerCase().contains(lower) ||
          i.nameEn.toLowerCase().contains(lower)).toList();
    }

    results = await Future.wait(results.map((i) async {
      final stats = await _reviewRepo.getProductStats('ink', i.id);
      return i.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
    }));

    return results;
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
        .map((doc) => InkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((i) =>
            i.brand.toLowerCase().contains(lower) ||
            i.name.toLowerCase().contains(lower) ||
            i.nameEn.toLowerCase().contains(lower))
        .toList();
  }

  // 동일 브랜드+이름 잉크 존재 여부 확인
  Future<bool> inkExists(String brand, String name) async {
    final snap = await _inks
        .where('brand', isEqualTo: brand)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // 잉크 등록 자동완성용 — 기존 브랜드/이름 목록 반환
  Future<({List<String> brands, List<String> names})> getInkFieldSuggestions() async {
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
    return (
      brands: (brands.toList()..sort()),
      names: (names.toList()..sort()),
    );
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
  Future<List<PenModel>> getPens({
    List<String>? brands, String? nibSize, String? nibMaterial,
    String? fillType, String? search, Object? lastDoc, int limit = 500,
  }) async {
    debugPrint('getPens - collection path: ${_pens.path}');
    Query query = _pens;
    if (nibMaterial != null) query = query.where('nibMaterial', isEqualTo: nibMaterial);
    if (fillType != null) query = query.where('fillType', isEqualTo: fillType);
    if (nibSize != null) query = query.where('nibSizes', arrayContains: nibSize);

    query = query.limit(limit);
    final snapshot = await query.get();
    debugPrint('getPens snapshot size: ${snapshot.docs.length}');
    var results = snapshot.docs
        .map((doc) => PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((p) => p.brand.isNotEmpty && p.modelName.isNotEmpty)
        .toList();

    if (brands != null && brands.isNotEmpty) {
      results = results.where((p) => brands.contains(p.brand)).toList();
    }

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      results = results.where((p) => p.brand.toLowerCase().contains(lower) || p.modelName.toLowerCase().contains(lower)).toList();
    }

    results = await Future.wait(results.map((p) async {
      final stats = await _reviewRepo.getProductStats('pen', p.id);
      return p.copyWith(reviewCount: stats.$1, avgRating: stats.$2);
    }));

    return results;
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
        .map((doc) => PenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((p) => p.brand.toLowerCase().contains(lower) || p.modelName.toLowerCase().contains(lower))
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
    required String nibMaterial,
    required List<String> nibSizes,
    required String fillType,
    String lineup = '',
    String priceRange = '',
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
      'addedBy': uid,
      'isUserAdded': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── 제품 신고 ────────────────────────────────────────────────────
  Future<void> reportProduct({
    required String targetType,
    required String targetId,
    required String targetName,
    required String reporterId,
    required String reason,
    String detail = '',
  }) async {
    await _firestore.collection(AppConstants.reportsCol).add({
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'reporterId': reporterId,
      'reason': reason,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted.take(topN).map((e) => e.key).toList();
    final inks = await Future.wait(ids.map(getInk));
    return inks.whereType<InkModel>().toList();
  }
}
