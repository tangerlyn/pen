import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/providers/providers.dart';

/// 아카이브 잉크 전체 목록 — 앱 실행 중 한 번만 읽어 캐시한다.
/// (기존 searchInks는 글자를 칠 때마다 컬렉션 전체를 다시 읽음)
final inkCatalogProvider = FutureProvider<List<InkModel>>((ref) {
  return ref.read(archiveRepoProvider).getInkCatalog();
});

class InkMatchQuery {
  const InkMatchQuery({
    this.text = '',
    this.colorFamilies = const {},
    this.brands = const {},
  });

  final String text;
  final Set<String> colorFamilies;
  final Set<String> brands;

  int get filterCount => colorFamilies.length + brands.length;
  bool get isEmpty => text.trim().isEmpty && filterCount == 0;
}

/// 잉크 매칭 검색. 검색어는 공백으로 나눈 단어가 모두 "브랜드 이름 영문명" 안에
/// 들어 있어야 맞는 것으로 본다 ("pilot kon" → Pilot Kon-peki).
/// 정렬: 이름이 검색어로 시작 → 전체 검색어 포함 → 나머지, 같은 순위는 브랜드·이름순.
List<InkModel> filterInks(
  List<InkModel> inks,
  InkMatchQuery query, {
  int limit = 50,
}) {
  final text = query.text.trim().toLowerCase();
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  final matched = inks.where((i) {
    if (query.colorFamilies.isNotEmpty &&
        !query.colorFamilies.contains(i.autoColorFamily)) {
      return false;
    }
    if (query.brands.isNotEmpty && !query.brands.contains(i.brand)) {
      return false;
    }
    if (words.isEmpty) return true;
    final haystack = '${i.brand} ${i.name} ${i.nameEn}'.toLowerCase();
    return words.every(haystack.contains);
  }).toList();

  int rank(InkModel i) {
    if (text.isEmpty) return 0;
    if (i.name.toLowerCase().startsWith(text) ||
        i.nameEn.toLowerCase().startsWith(text)) {
      return 0;
    }
    if ('${i.brand} ${i.name}'.toLowerCase().contains(text)) return 1;
    return 2;
  }

  matched.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final br = a.brand.compareTo(b.brand);
    return br != 0 ? br : a.name.compareTo(b.name);
  });
  return matched.take(limit).toList();
}

/// 브랜드 칩 목록 — 잉크가 많은 브랜드부터
List<String> brandsByInkCount(List<InkModel> inks) {
  final counts = <String, int>{};
  for (final i in inks) {
    counts[i.brand] = (counts[i.brand] ?? 0) + 1;
  }
  final brands = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return brands;
}
