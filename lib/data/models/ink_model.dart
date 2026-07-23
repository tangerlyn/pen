import 'package:flutter/material.dart';

class InkModel {
  const InkModel({
    required this.id,
    required this.brand,
    required this.name,
    this.nameEn = '',
    this.inkType = 'normal',
    this.hexColor = '',
    this.capacityMl = 0,
    this.reviewCount = 0,
    this.avgRating = 0.0,
  });

  final String id;
  final String brand;
  final String name;
  // 영문 원어 이름 — 화면엔 노출하지 않고 검색 매칭에만 사용 (예: name='임페리얼 블루', nameEn='Imperial Blue')
  final String nameEn;
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
    if (hexColor.isEmpty) return '검정';
    try {
      final color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
      final hsv = HSVColor.fromColor(color);
      // 거의 검게 보이는 색은 색상값(hue)이 불안정해지므로 채도/명도로 먼저 걸러낸다
      // (예: 매우 어두운 잉크가 hue 계산상 우연히 '노랑' 범위에 들어가는 경우 방지)
      if (hsv.value < 0.13 || hsv.saturation < 0.15) return '검정';
      final hue = hsv.hue;
      if (hue < 20 || hue >= 330) return '빨강';
      if (hue < 35) return '주황';
      if (hue < 70) return '노랑';
      if (hue < 170) return '초록';
      if (hue < 255) return '파랑';
      return '보라';
    } catch (_) {
      return '검정';
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
      nameEn: data['nameEn'] as String? ?? '',
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
        'nameEn': nameEn,
        'inkType': inkType,
        'hexColor': hexColor,
        'capacityMl': capacityMl,
        'reviewCount': reviewCount,
        'avgRating': avgRating,
      };

  InkModel copyWith({
    String? id, String? brand, String? name, String? nameEn,
    String? inkType, String? hexColor, int? capacityMl, int? reviewCount, double? avgRating,
  }) {
    return InkModel(
      id: id ?? this.id, brand: brand ?? this.brand, name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      inkType: inkType ?? this.inkType,
      hexColor: hexColor ?? this.hexColor, capacityMl: capacityMl ?? this.capacityMl,
      reviewCount: reviewCount ?? this.reviewCount, avgRating: avgRating ?? this.avgRating,
    );
  }
}
