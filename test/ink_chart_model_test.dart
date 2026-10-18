import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/data/models/ink_chart_model.dart';

void main() {
  final created = DateTime(2026, 3, 1, 9);

  // 스와치 기록 플로우 이전에 저장된 문서 모양 그대로
  Map<String, dynamic> legacyDoc() => {
        'photoUrl': 'https://example.com/a.png',
        'brand': 'Pilot',
        'inkName': 'Kon-peki',
        'memo': '맑은 파랑',
        'order': 3,
        'createdAt': Timestamp.fromDate(created),
      };

  test('기존 잉크 차트 문서는 값 변화 없이 읽히고 새 필드는 모두 null', () {
    final m = InkChartModel.fromMap(legacyDoc(), 'c1');
    expect(m.id, 'c1');
    expect(m.brand, 'Pilot');
    expect(m.inkName, 'Kon-peki');
    expect(m.memo, '맑은 파랑');
    expect(m.order, 3);
    expect(m.createdAt, created);
    expect(m.inkId, isNull);
    expect(m.penName, isNull);
    expect(m.nibSize, isNull);
    expect(m.paperName, isNull);
    expect(m.recordedAt, isNull);
    expect(m.recordDate, created, reason: '기록 날짜가 없으면 생성 시각으로 정렬');
  });

  test('새 필드가 있는 문서를 읽으면 그대로 복원되고, 빈 문자열은 null로 본다', () {
    final recorded = DateTime(2026, 2, 14);
    final m = InkChartModel.fromMap({
      ...legacyDoc(),
      'brand': '',
      'inkId': 'ink42',
      'penName': 'Custom 74',
      'nibSize': '',
      'paperName': 'Tomoe River',
      'recordedAt': Timestamp.fromDate(recorded),
    }, 'c2');
    expect(m.inkId, 'ink42');
    expect(m.penName, 'Custom 74');
    expect(m.nibSize, isNull);
    expect(m.paperName, 'Tomoe River');
    expect(m.recordDate, recorded);
    expect(m.displayName, 'Kon-peki', reason: '브랜드가 없으면 잉크 이름만');
  });

  test('toMap은 비어 있는 선택 필드를 문서에 쓰지 않는다 (구버전과 같은 모양)', () {
    final m = InkChartModel.fromMap(legacyDoc(), 'c1');
    expect(
      m.toMap().keys.toSet(),
      {'photoUrl', 'brand', 'inkName', 'memo', 'order', 'createdAt'},
    );
  });

  test('수정용 선택 필드 맵은 비운 필드를 삭제로 표시한다', () {
    final m = InkChartModel(
      id: 'c3',
      photoUrl: 'u',
      brand: '',
      inkName: 'Ink',
      createdAt: created,
      penName: 'Pen',
    );
    final forCreate = m.optionalFieldsMap(deleteMissing: false);
    expect(forCreate, {'penName': 'Pen'});

    final forUpdate = m.optionalFieldsMap(deleteMissing: true);
    expect(forUpdate['penName'], 'Pen');
    for (final key in ['inkId', 'nibSize', 'paperName', 'recordedAt']) {
      expect(forUpdate[key], isA<FieldValue>(), reason: key);
    }
  });

  test('copyWith(order)는 선택 필드를 잃지 않는다 (공책 화면 순서 변경)', () {
    final m = InkChartModel(
      id: 'c4',
      photoUrl: 'u',
      brand: 'B',
      inkName: 'Ink',
      createdAt: created,
      inkId: 'ink1',
      recordedAt: created,
    ).copyWith(order: 7);
    expect(m.order, 7);
    expect(m.inkId, 'ink1');
    expect(m.recordedAt, created);
  });
}
