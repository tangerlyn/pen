class PenModel {
  const PenModel({
    required this.id,
    required this.brand,
    this.lineup = '',
    required this.modelName,
    this.nibSizes = const [],
    this.nibMaterial = '스틸닙',
    this.fillType = '카트리지·컨버터',
    this.priceRange = '',
    this.reviewCount = 0,
    this.avgRating = 0.0,
    this.photoUrl,
  });

  final String id;
  final String brand;
  final String lineup;
  final String modelName;
  final List<String> nibSizes;
  final String nibMaterial;
  final String fillType;
  final String priceRange;
  final int reviewCount;
  final double avgRating;
  final String? photoUrl;

  String get displayName => '$brand $modelName';

  factory PenModel.fromMap(Map<String, dynamic> data, String id) {
    return PenModel(
      id: id,
      brand: data['brand'] as String? ?? '',
      lineup: data['lineup'] as String? ?? '',
      modelName: data['modelName'] as String? ?? '',
      nibSizes: List<String>.from(data['nibSizes'] as List? ?? []),
      nibMaterial: data['nibMaterial'] as String? ?? '스틸닙',
      fillType: data['fillType'] as String? ?? '카트리지·컨버터',
      priceRange: data['priceRange'] as String? ?? '',
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'brand': brand,
        'lineup': lineup,
        'modelName': modelName,
        'nibSizes': nibSizes,
        'nibMaterial': nibMaterial,
        'fillType': fillType,
        'priceRange': priceRange,
        'reviewCount': reviewCount,
        'avgRating': avgRating,
        'photoUrl': photoUrl,
      };

  PenModel copyWith({
    String? id, String? brand, String? lineup, String? modelName,
    List<String>? nibSizes, String? nibMaterial, String? fillType,
    String? priceRange, int? reviewCount, double? avgRating, String? photoUrl,
  }) {
    return PenModel(
      id: id ?? this.id, brand: brand ?? this.brand, lineup: lineup ?? this.lineup,
      modelName: modelName ?? this.modelName, nibSizes: nibSizes ?? this.nibSizes,
      nibMaterial: nibMaterial ?? this.nibMaterial, fillType: fillType ?? this.fillType,
      priceRange: priceRange ?? this.priceRange, reviewCount: reviewCount ?? this.reviewCount,
      avgRating: avgRating ?? this.avgRating, photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
