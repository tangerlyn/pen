import 'package:cloud_firestore/cloud_firestore.dart';

class InkChartModel {
  const InkChartModel({
    required this.id,
    required this.photoUrl,
    required this.brand,
    required this.inkName,
    this.memo = '',
    required this.createdAt,
    this.order = 0,
  });

  final String id;
  final String photoUrl;
  final String brand;
  final String inkName;
  final String memo;
  final DateTime createdAt;
  final int order;

  factory InkChartModel.fromMap(Map<String, dynamic> data, String id) => InkChartModel(
        id: id,
        photoUrl: data['photoUrl'] as String? ?? '',
        brand: data['brand'] as String? ?? '',
        inkName: data['inkName'] as String? ?? '',
        memo: data['memo'] as String? ?? '',
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
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };

  InkChartModel copyWith({int? order}) => InkChartModel(
        id: id,
        photoUrl: photoUrl,
        brand: brand,
        inkName: inkName,
        memo: memo,
        createdAt: createdAt,
        order: order ?? this.order,
      );
}
