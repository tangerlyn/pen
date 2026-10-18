import 'package:cloud_firestore/cloud_firestore.dart';

class InkChartModel {
  const InkChartModel({
    required this.id,
    required this.photoUrl,
    required this.brand,
    required this.inkName,
    this.memo = '',
    this.contentBlocks,
    required this.createdAt,
    this.order = 0,
    this.inkId,
    this.penName,
    this.nibSize,
    this.paperName,
    this.recordedAt,
  });

  final String id;
  final String photoUrl;
  // 스와치 기록 플로우에서는 선택 입력이라 빈 문자열일 수 있음
  final String brand;
  final String inkName;
  final String memo;
  // 메모 블로그 형식 본문(텍스트+이미지 블록) — null이면 memo(텍스트)만 사용
  final List<Map<String, dynamic>>? contentBlocks;
  final DateTime createdAt;
  final int order;

  // ── 스와치 기록 플로우에서 추가된 선택 필드 ──────────────────────────
  // 예전 문서에는 없으므로 전부 null 허용. 값이 있을 때만 문서에 쓴다.
  /// 아카이브 `inks` 문서 ID — 직접 입력한 잉크면 null
  final String? inkId;
  final String? penName;
  final String? nibSize;
  final String? paperName;
  /// 사용자가 고른 기록 날짜 — 없으면 createdAt을 기록 날짜로 본다
  final DateTime? recordedAt;

  /// 기록 홈 정렬·타임라인에 쓰는 날짜
  DateTime get recordDate => recordedAt ?? createdAt;

  String get displayName => brand.isEmpty ? inkName : '$brand $inkName';

  factory InkChartModel.fromMap(Map<String, dynamic> data, String id) => InkChartModel(
        id: id,
        photoUrl: data['photoUrl'] as String? ?? '',
        brand: data['brand'] as String? ?? '',
        inkName: data['inkName'] as String? ?? '',
        memo: data['memo'] as String? ?? '',
        contentBlocks: (data['contentBlocks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        order: data['order'] as int? ?? 0,
        inkId: _nonEmpty(data['inkId']),
        penName: _nonEmpty(data['penName']),
        nibSize: _nonEmpty(data['nibSize']),
        paperName: _nonEmpty(data['paperName']),
        recordedAt: data['recordedAt'] is Timestamp
            ? (data['recordedAt'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'photoUrl': photoUrl,
        'brand': brand,
        'inkName': inkName,
        'memo': memo,
        if (contentBlocks != null) 'contentBlocks': contentBlocks,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
        ...optionalFieldsMap(deleteMissing: false),
      };

  /// 선택 필드만 담은 맵. [deleteMissing]이면 비어 있는 필드를 FieldValue.delete()로
  /// 채워서, 수정 시 사용자가 지운 값이 문서에서도 지워지게 한다.
  Map<String, dynamic> optionalFieldsMap({required bool deleteMissing}) {
    final values = <String, Object?>{
      'inkId': inkId,
      'penName': penName,
      'nibSize': nibSize,
      'paperName': paperName,
      'recordedAt': recordedAt == null ? null : Timestamp.fromDate(recordedAt!),
    };
    return {
      for (final e in values.entries)
        if (e.value != null && e.value != '')
          e.key: e.value
        else if (deleteMissing)
          e.key: FieldValue.delete(),
    };
  }

  InkChartModel copyWith({int? order}) => InkChartModel(
        id: id,
        photoUrl: photoUrl,
        brand: brand,
        inkName: inkName,
        memo: memo,
        contentBlocks: contentBlocks,
        createdAt: createdAt,
        order: order ?? this.order,
        inkId: inkId,
        penName: penName,
        nibSize: nibSize,
        paperName: paperName,
        recordedAt: recordedAt,
      );

  static String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
