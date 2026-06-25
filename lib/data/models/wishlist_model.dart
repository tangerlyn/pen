import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.brand,
    this.hexColor = '',
    required this.createdAt,
  });

  final String id;
  final String type; // 'ink' | 'pen'
  final String productId;
  final String productName;
  final String brand;
  final String hexColor;
  final DateTime createdAt;

  String get displayName => '$brand $productName';

  factory WishlistItem.fromMap(Map<String, dynamic> data, String id) => WishlistItem(
        id: id,
        type: data['type'] as String? ?? 'ink',
        productId: data['productId'] as String? ?? '',
        productName: data['productName'] as String? ?? '',
        brand: data['brand'] as String? ?? '',
        hexColor: data['hexColor'] as String? ?? '',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'productId': productId,
        'productName': productName,
        'brand': brand,
        'hexColor': hexColor,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
