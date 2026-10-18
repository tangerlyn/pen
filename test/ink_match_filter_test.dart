import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/data/models/ink_model.dart';
import 'package:nibpen/features/record/providers/ink_catalog_provider.dart';

void main() {
  const konpeki = InkModel(id: '1', brand: 'Pilot', name: '콘페키', nameEn: 'Kon-peki', hexColor: '#1E88E5');
  const tsuyu = InkModel(id: '2', brand: 'Pilot', name: '츠유쿠사', nameEn: 'Tsuyu-kusa', hexColor: '#3F51B5');
  const oxblood = InkModel(id: '3', brand: 'Diamine', name: 'Oxblood', hexColor: '#7B1E1E');
  const konBlack = InkModel(id: '4', brand: 'Sailor', name: 'Kon Black', hexColor: '#111111');
  const catalog = [oxblood, konBlack, tsuyu, konpeki];

  List<String> ids(List<InkModel> inks) => inks.map((i) => i.id).toList();

  test('검색어가 비고 필터도 없으면 전체를 브랜드·이름순으로', () {
    // Pilot 안에서는 한글 이름순: 츠유쿠사 < 콘페키
    expect(ids(filterInks(catalog, const InkMatchQuery())), ['3', '2', '1', '4']);
  });

  test('여러 단어 검색은 모든 단어가 브랜드·이름·영문명 어딘가에 있어야 한다', () {
    expect(ids(filterInks(catalog, const InkMatchQuery(text: 'pilot kon'))), ['1']);
    expect(ids(filterInks(catalog, const InkMatchQuery(text: '  OXBLOOD '))), ['3']);
  });

  test('이름(영문명)이 검색어로 시작하는 잉크가 먼저 나온다', () {
    const brandOnlyKon = InkModel(id: '5', brand: 'Kon', name: 'Ink', hexColor: '#000000');
    // 5는 브랜드만 맞아서 이름이 'kon'으로 시작하는 1·4보다 뒤
    expect(ids(filterInks([brandOnlyKon, ...catalog], const InkMatchQuery(text: 'kon'))), ['1', '4', '5']);
    expect(ids(filterInks(catalog, const InkMatchQuery(text: 'kon-'))), ['1']);
  });

  test('색 계열·브랜드 필터는 검색어와 함께 AND로 적용된다', () {
    expect(
      ids(filterInks(catalog, const InkMatchQuery(colorFamilies: {'파랑'}))),
      ['2', '1'],
    );
    expect(
      ids(filterInks(catalog, const InkMatchQuery(colorFamilies: {'파랑'}, brands: {'Sailor'}))),
      isEmpty,
    );
    expect(
      ids(filterInks(catalog, const InkMatchQuery(text: 'kon', brands: {'Sailor'}))),
      ['4'],
    );
    expect(const InkMatchQuery(colorFamilies: {'파랑'}, brands: {'Pilot'}).filterCount, 2);
  });

  test('결과 수는 limit으로 자른다', () {
    expect(filterInks(catalog, const InkMatchQuery(), limit: 2), hasLength(2));
  });

  test('브랜드 칩은 잉크가 많은 브랜드부터, 같으면 이름순', () {
    expect(brandsByInkCount(catalog), ['Pilot', 'Diamine', 'Sailor']);
  });
}
