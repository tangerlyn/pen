import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 'public' | 'followers' | 'private'
typedef BookVisibility = String;

class InkBookModel {
  const InkBookModel({
    required this.id,
    required this.name,
    required this.coverColor,
    required this.createdAt,
    this.visibility = 'public',
    this.ownerUid = '',
    this.ownerNickname = '',
    this.pageStyle = 'lines',
    this.viewMode = 'pageView',
  });

  final String id;
  final String name;
  final String coverColor; // '#RRGGBB'
  final DateTime createdAt;
  final BookVisibility visibility; // 'public' | 'followers' | 'private'
  final String ownerUid;
  final String ownerNickname;
  final String pageStyle; // 'lines' | 'grid' | 'plain'
  final String viewMode; // 'pageView' | 'scroll'

  bool get isPublic => visibility == 'public';

  Color get color {
    final hex = coverColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory InkBookModel.fromMap(Map<String, dynamic> data, String id) => InkBookModel(
        id: id,
        name: data['name'] as String? ?? '내 공책',
        coverColor: data['coverColor'] as String? ?? '#C8D8B0',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        // 구버전 isPublic bool 필드 하위 호환
        visibility: data['visibility'] as String? ??
            ((data['isPublic'] as bool? ?? false) ? 'public' : 'private'),
        ownerUid: data['ownerUid'] as String? ?? '',
        ownerNickname: data['ownerNickname'] as String? ?? '',
        pageStyle: data['pageStyle'] as String? ?? 'lines',
        viewMode: data['viewMode'] as String? ?? 'pageView',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'coverColor': coverColor,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': visibility,
        'isPublic': visibility == 'public', // 구버전 쿼리 하위 호환
        'ownerUid': ownerUid,
        'ownerNickname': ownerNickname,
        'pageStyle': pageStyle,
        'viewMode': viewMode,
      };

  InkBookModel copyWith({
    String? visibility,
    String? ownerNickname,
    String? pageStyle,
    String? viewMode,
  }) =>
      InkBookModel(
        id: id,
        name: name,
        coverColor: coverColor,
        createdAt: createdAt,
        visibility: visibility ?? this.visibility,
        ownerUid: ownerUid,
        ownerNickname: ownerNickname ?? this.ownerNickname,
        pageStyle: pageStyle ?? this.pageStyle,
        viewMode: viewMode ?? this.viewMode,
      );
}

/// 공책 표지색 선택용 고정 팔레트 (빨주노초파보라검정 7색).
/// 카드 자체에서 옅게 처리하므로 여기 값은 원색에 가깝게 둔다.
const kInkBookCoverColors = [
  '#F44336', // 빨강
  '#FF9800', // 주황
  '#FFEB3B', // 노랑
  '#4CAF50', // 초록
  '#2196F3', // 파랑
  '#9C27B0', // 보라
  '#000000', // 검정
];
