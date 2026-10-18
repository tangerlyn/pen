import 'package:flutter/painting.dart';

/// 잉크 색 계열 — 이름 → 칩에 보여줄 대표 색상.
/// 이름은 `InkModel.autoColorFamily`가 돌려주는 값과 같아야 필터가 맞는다.
const kInkColorFamilySwatches = {
  '빨강': Color(0xFFE53935),
  '주황': Color(0xFFFB8C00),
  '노랑': Color(0xFFFDD835),
  '초록': Color(0xFF43A047),
  '파랑': Color(0xFF1E88E5),
  '보라': Color(0xFF8E24AA),
  '검정': Color(0xFF2B2B2B),
};
