import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';
import '../../../features/archive/providers/archive_detail_provider.dart';

/// 리뷰 사진 위에 얹는 태그 물품 이름 (흰 글씨).
/// 1개면 "이름", 2개 이상이면 "이름 +N". 이름이 길면 이름만 "…"로 줄이고
/// "+N"은 항상 보이게 한다.
class ReviewGearTagLabel extends ConsumerWidget {
  const ReviewGearTagLabel({
    super.key,
    required this.review,
    this.fontSize = 13,
  });

  final ReviewModel review;
  final double fontSize;

  static bool hasTags(ReviewModel review) =>
      review.inkIds.isNotEmpty || review.penIds.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasTags(review)) return const SizedBox.shrink();
    final first = review.inkIds.isNotEmpty
        ? (type: 'ink', id: review.inkIds.first)
        : (type: 'pen', id: review.penIds.first);
    final others = review.inkIds.length + review.penIds.length - 1;

    final data = ref
        .watch(archiveDetailProvider((type: first.type, productId: first.id)))
        .valueOrNull;
    final String name = data == null
        ? ''
        : (first.type == 'ink' ? data.name : data.modelName) as String? ?? '';
    if (name.isEmpty) return const SizedBox.shrink();

    final style = AppTextStyles.labelMedium.copyWith(
      fontSize: fontSize,
      color: Colors.white,
      fontWeight: FontWeight.w600,
      shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (others > 0)
          Text(' +$others', maxLines: 1, softWrap: false, style: style),
      ],
    );
  }
}

/// 사진 하단의 옅은 검은 그라데이션 + 태그 이름. Stack 안에 넣어 쓴다.
class ReviewGearTagOverlay extends StatelessWidget {
  const ReviewGearTagOverlay({
    super.key,
    required this.review,
    this.fontSize = 13,
    this.padding = 8,
  });

  final ReviewModel review;
  final double fontSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    if (!ReviewGearTagLabel.hasTags(review)) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            padding,
            padding * 2.5,
            padding,
            padding,
          ),
          child: ReviewGearTagLabel(review: review, fontSize: fontSize),
        ),
      ),
    );
  }
}
