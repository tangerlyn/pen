import 'package:flutter/rendering.dart';

/// [base] 델리게이트의 레이아웃을 그대로 쓰되, 셀 세로 길이가
/// [minMainAxisExtent]보다 작아지면 그 값까지만 늘린다.
///
/// 비율(childAspectRatio) 고정 그리드는 좁은 화면이나 큰 글자 크기에서
/// 셀 안 텍스트가 넘치는 문제가 있어서, 기본 크기에서는 기존 모양을
/// 유지하고 내용이 더 필요할 때만 셀이 길어지게 한다.
class MinExtentGridDelegate extends SliverGridDelegate {
  const MinExtentGridDelegate({
    required this.base,
    required this.minMainAxisExtent,
  });

  final SliverGridDelegate base;
  final double minMainAxisExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final layout = base.getLayout(constraints);
    if (layout is! SliverGridRegularTileLayout ||
        layout.childMainAxisExtent >= minMainAxisExtent) {
      return layout;
    }
    final spacing = layout.mainAxisStride - layout.childMainAxisExtent;
    return SliverGridRegularTileLayout(
      crossAxisCount: layout.crossAxisCount,
      mainAxisStride: minMainAxisExtent + spacing,
      crossAxisStride: layout.crossAxisStride,
      childMainAxisExtent: minMainAxisExtent,
      childCrossAxisExtent: layout.childCrossAxisExtent,
      reverseCrossAxis: layout.reverseCrossAxis,
    );
  }

  @override
  bool shouldRelayout(MinExtentGridDelegate oldDelegate) =>
      oldDelegate.minMainAxisExtent != minMainAxisExtent ||
      oldDelegate.base.runtimeType != base.runtimeType ||
      base.shouldRelayout(oldDelegate.base);
}
