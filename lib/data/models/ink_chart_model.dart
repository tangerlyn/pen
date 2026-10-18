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
  });

  final String id;
  final String photoUrl;
  final String brand;
  final String inkName;
  final String memo;
  // 메모 블로그 형식 본문(텍스트+이미지 블록) — null이면 memo(텍스트)만 사용
  final List<Map<String, dynamic>>? contentBlocks;
  final DateTime createdAt;
  final int order;

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
      );

  Map<String, dynamic> toMap() => {
        'photoUrl': photoUrl,
        'brand': brand,
        'inkName': inkName,
        'memo': memo,
        if (contentBlocks != null) 'contentBlocks': contentBlocks,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };

  InkChartModel copyWith({int? order}) => InkChartModel(
        id: id,
        photoUrl: photoUrl,
        brand: brand,
        inkName: inkName,
        memo: memo,
        contentBlocks: contentBlocks,
        createdAt: createdAt,
        order: order ?? this.order,
      );
}
