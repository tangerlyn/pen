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
  });

  final String id;
  final String name;
  final String coverColor; // '#RRGGBB'
  final DateTime createdAt;
  final BookVisibility visibility; // 'public' | 'followers' | 'private'
  final String ownerUid;
  final String ownerNickname;

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
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'coverColor': coverColor,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': visibility,
        'isPublic': visibility == 'public', // 구버전 쿼리 하위 호환
        'ownerUid': ownerUid,
        'ownerNickname': ownerNickname,
      };

  InkBookModel copyWith({String? visibility, String? ownerNickname}) => InkBookModel(
        id: id,
        name: name,
        coverColor: coverColor,
        createdAt: createdAt,
        visibility: visibility ?? this.visibility,
        ownerUid: ownerUid,
        ownerNickname: ownerNickname ?? this.ownerNickname,
      );
}

/// 파스텔 팔레트 (공책 표지색 선택용)
const kPastelColors = [
  '#C8D8B0', // sage green
  '#B8D4E8', // sky blue
  '#E8C8B0', // peach
  '#D4B8E8', // lavender
  '#E8D4B8', // warm sand
  '#B8E8D4', // mint
  '#E8B8C8', // blush
  '#E8E0B8', // butter
  '#B8C8E8', // periwinkle
  '#C8B8D4', // mauve
  '#B8D8C8', // seafoam
  '#E8C8D8', // rose
];
