import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../shared/providers/ink_book_providers.dart';

/// 공책(잉크북) 카드 — 스프링 바인딩 척추 + 표지 형태.
/// 내 잉크 차트 목록과 다른 유저의 잉크 차트 목록이 동일한 "책 모양"으로
/// 보이도록 공유한다.
///
/// 표지는 불투명 단색 대신, 유저가 고른 표지 색을 옅은 그라데이션으로 깔고
/// 그 위에 반투명 프로스티드 글래스(AppGlass)를 덮는 방식이다 — 앱 전체
/// 배경(AppGlass)을 만드는 것과 같은 처리를 표지색에도 그대로 적용해서,
/// 어떤 색을 골라도 그 색의 옅은 유리 카드로 보이게 한다.
class NotebookCard extends ConsumerWidget {
  const NotebookCard({
    super.key,
    required this.book,
    required this.uid,
    required this.onTap,
    this.onLongPress,
    this.onMenuTap,
  });

  final InkBookModel book;
  final String uid;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 카드 오른쪽 위 ⋮ 버튼 콜백 — null이면 버튼 자체가 안 보인다(다른
  /// 유저의 공책을 읽기 전용으로 보여줄 때는 전달하지 않는다).
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(inkChartInBookProvider((uid, book.id)));
    final count = countAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final accentColor = book.color;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            children: [
              // 표지색 워시 — 유리 뒤에 비치는 유저가 고른 색
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: 0.78),
                        accentColor.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              // 프로스티드 글래스
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppGlass.blur,
                    sigmaY: AppGlass.blur,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppGlass.cardColor,
                      border: Border.all(color: AppGlass.cardBorderColor),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 스프링 바인딩 척추 — 얇은 색 띠 + 링 장식만 남겨 가볍게
                  SizedBox(
                    width: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        5,
                        (_) => Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 표지 본체
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 줄 장식
                          Container(
                            height: 1.5,
                            color: accentColor.withValues(alpha: 0.25),
                            margin: const EdgeInsets.only(bottom: 12),
                          ),
                          const Spacer(),
                          // 공책 이름
                          Text(
                            book.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count개',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (onMenuTap != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onMenuTap,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.more_vert,
                          size: 22,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
