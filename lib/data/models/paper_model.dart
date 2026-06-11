class PaperModel {
  const PaperModel({
    required this.id,
    required this.brand,
    required this.productName,
    this.rulingType = '무지',
    this.grammage = 0,
    this.size = '',
    this.coverType = '',
    this.reviewCount = 0,
    this.avgRating = 0.0,
  });

  final String id;
  final String brand;
  final String productName;
  final String rulingType;
  final int grammage;
  final String size;
  final String coverType;
  final int reviewCount;
  final double avgRating;

  String get displayName => '$brand $productName';

  factory PaperModel.fromMap(Map<String, dynamic> data, String id) {
    return PaperModel(
      id: id,
      brand: data['brand'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      rulingType: data['rulingType'] as String? ?? '무지',
      grammage: (data['grammage'] as num?)?.toInt() ?? 0,
      size: data['size'] as String? ?? '',
      coverType: data['coverType'] as String? ?? '',
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'brand': brand,
        'productName': productName,
        'rulingType': rulingType,
        'grammage': grammage,
        'size': size,
        'coverType': coverType,
        'reviewCount': reviewCount,
        'avgRating': avgRating,
      };

  PaperModel copyWith({
    String? id, String? brand, String? productName, String? rulingType,
    int? grammage, String? size, String? coverType, int? reviewCount, double? avgRating,
  }) {
    return PaperModel(
      id: id ?? this.id, brand: brand ?? this.brand, productName: productName ?? this.productName,
      rulingType: rulingType ?? this.rulingType, grammage: grammage ?? this.grammage,
      size: size ?? this.size, coverType: coverType ?? this.coverType,
      reviewCount: reviewCount ?? this.reviewCount, avgRating: avgRating ?? this.avgRating,
    );
  }
}
