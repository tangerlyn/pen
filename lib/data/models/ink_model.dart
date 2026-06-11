import 'package:flutter/material.dart';

class InkModel {
  const InkModel({
    required this.id,
    required this.brand,
    required this.name,
    this.inkType = 'normal',
    this.hexColor = '',
    this.capacityMl = 0,
    this.reviewCount = 0,
    this.avgRating = 0.0,
  });

  final String id;
  final String brand;
  final String name;
  final String inkType; // normal / shimmer / sheen / fluorescent
  final String hexColor;
  final int capacityMl;
  final int reviewCount;
  final double avgRating;

  String get displayName => '$brand $name';

  String get inkTypeLabel {
    switch (inkType) {
      case 'shimmer': return '펄';
      case 'sheen': return '테';
      default: return '일반';
    }
  }

  String get autoColorFamily {
    if (hexColor.isEmpty) return '기타';
    try {
      final color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
      final hsv = HSVColor.fromColor(color);
      if (hsv.saturation < 0.15) return '무채색';
      final hue = hsv.hue;
      if (hue < 15 || hue >= 345) return '레드';
      if (hue < 45) return '오렌지';
      if (hue < 75) return '옐로우';
      if (hue < 165) return '그린';
      if (hue < 195) return '시안';
      if (hue < 255) return '블루';
      if (hue < 285) return '퍼플';
      if (hue < 345) return '핑크';
      return '기타';
    } catch (_) {
      return '기타';
    }
  }

  Color get inkColor {
    if (hexColor.isEmpty) return Colors.grey.shade300;
    try {
      return Color(int.parse('FF${hexColor.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey.shade300;
    }
  }

  factory InkModel.fromMap(Map<String, dynamic> data, String id) {
    return InkModel(
      id: id,
      brand: data['brand'] as String? ?? '',
      name: data['name'] as String? ?? '',
      inkType: data['inkType'] as String? ?? 'normal',
      hexColor: data['hexColor'] as String? ?? '',
      capacityMl: (data['capacityMl'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'brand': brand,
        'name': name,
        'inkType': inkType,
        'hexColor': hexColor,
        'capacityMl': capacityMl,
        'reviewCount': reviewCount,
        'avgRating': avgRating,
      };

  InkModel copyWith({
    String? id, String? brand, String? name,
    String? inkType, String? hexColor, int? capacityMl, int? reviewCount, double? avgRating,
  }) {
    return InkModel(
      id: id ?? this.id, brand: brand ?? this.brand, name: name ?? this.name,
      inkType: inkType ?? this.inkType,
      hexColor: hexColor ?? this.hexColor, capacityMl: capacityMl ?? this.capacityMl,
      reviewCount: reviewCount ?? this.reviewCount, avgRating: avgRating ?? this.avgRating,
    );
  }
}
