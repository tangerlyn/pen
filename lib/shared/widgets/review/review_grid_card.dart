import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/post_date_format.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/providers.dart';
import '../level_badge.dart';
import '../tap_scale.dart';
import '../user_avatar.dart';
import 'review_gear_tag_label.dart';

final _gridCardAuthorProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(userRepoProvider).watchUser(uid);
});

/// 리뷰 탭 3열 그리드 카드: 사진(4:5) 아래에 작성자 · 제목 · 본문 한 줄 · 상대 시간.
class ReviewGridCard extends ConsumerWidget {
  const ReviewGridCard({super.key, required this.review, required this.onTap});

  final ReviewModel review;
  final VoidCallback onTap;

  static const imageAspectRatio = 4 / 5;
  static const _hPad = 6.0;

  // 글 줄마다 높이를 고정(strut)해 두고, 칸 높이는 실제 글꼴로 재서 계산한다.
  // (어림값으로 계산하면 글꼴 줄 간격 차이로 1~3px 넘친다)
  static const _nameStyle = TextStyle(fontSize: 11, height: 1.3);
  static const _titleStyle = TextStyle(fontSize: 12, height: 1.35);
  static const _bodyStyle = TextStyle(fontSize: 11, height: 1.35);
  static const _dateStyle = TextStyle(fontSize: 10, height: 1.3);

  static StrutStyle _strut(TextStyle style) =>
      StrutStyle.fromTextStyle(style, forceStrutHeight: true);

  /// 실제로 그려질 글꼴·글자 크기 배율로 한 줄 높이를 잰다.
  static double _lineHeight(
    BuildContext context,
    TextStyle style, {
    bool forceStrut = true,
  }) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(text: 'Ag가', style: effective),
      strutStyle: forceStrut ? _strut(effective) : null,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final h = painter.height;
    painter.dispose();
    return h;
  }

  /// 사진 아래 글 영역 높이. 기기 글자 크기(최대 1.3배)에 맞춰 늘어난다.
  static double infoHeight(BuildContext context) {
    // 레벨 뱃지 = labelSmall 굵게 + 위아래 여백 2씩
    final badge =
        _lineHeight(
          context,
          AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
          forceStrut: false,
        ) +
        4;
    final authorRow = [
      16.0,
      badge,
      _lineHeight(context, _nameStyle),
    ].reduce((a, b) => a > b ? a : b);
    return 8 + // 위 여백
        authorRow +
        5 +
        _lineHeight(context, _titleStyle) +
        2 +
        _lineHeight(context, _bodyStyle) +
        4 +
        _lineHeight(context, _dateStyle) +
        4 + // 아래 여백
        1; // 반올림 오차 여유
  }

  /// 그리드 한 칸의 전체 높이 (사진 + 글 영역)
  static double extent(BuildContext context, double cellWidth) =>
      cellWidth / imageAspectRatio + infoHeight(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(_gridCardAuthorProvider(review.authorId))
        .valueOrNull;
    final nickname = user?.nickname ?? review.authorNickname;
    final body = review.body.replaceAll(RegExp(r'\s+'), ' ').trim();

    return TapScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: imageAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: review.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppColors.chipBackground),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.chipBackground,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                ),
                ReviewGearTagOverlay(review: review, fontSize: 11, padding: 6),
                if (review.imageUrls.length > 1)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.collections,
                      color: Colors.white,
                      size: 14,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: infoHeight(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: user?.profileImageUrl,
                        radius: 8,
                        iconSize: 10,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          strutStyle: _strut(_nameStyle),
                          style: _nameStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      LevelBadge(user?.level ?? review.authorLevel),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    review.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: _strut(_titleStyle),
                    style: _titleStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: _strut(_bodyStyle),
                    style: _bodyStyle.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeDate(review.createdAt),
                    maxLines: 1,
                    strutStyle: _strut(_dateStyle),
                    style: _dateStyle.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
