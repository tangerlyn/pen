import 'package:cloud_firestore/cloud_firestore.dart';

/// 내 컬렉션(보유 잉크). 문서 ID = 아카이브 잉크 ID라서 같은 잉크는 한 번만 담긴다.
class OwnedInk {
  const OwnedInk({
    required this.inkId,
    required this.brand,
    required this.name,
    this.hexColor = '',
    required this.createdAt,
  });

  final String inkId;
  final String brand;
  final String name;
  final String hexColor;
  final DateTime createdAt;

  factory OwnedInk.fromMap(Map<String, dynamic> data, String id) => OwnedInk(
        inkId: id,
        brand: data['brand'] as String? ?? '',
        name: data['name'] as String? ?? '',
        hexColor: data['hexColor'] as String? ?? '',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'inkId': inkId,
        'brand': brand,
        'name': name,
        'hexColor': hexColor,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
