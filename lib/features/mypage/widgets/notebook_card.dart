import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../shared/providers/ink_book_providers.dart';

/// 공책(잉크북) 카드 — 스프링 바인딩 척추 + 표지 형태.
/// 내 잉크 차트 목록과 다른 유저의 잉크 차트 목록이 동일한 "책 모양"으로
/// 보이도록 공유한다.
class NotebookCard extends ConsumerWidget {
  const NotebookCard({
    super.key,
    required this.book,
    required this.uid,
    required this.onTap,
    this.onLongPress,
  });

  final InkBookModel book;
  final String uid;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(inkChartInBookProvider((uid, book.id)));
    final count = countAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final coverColor = book.color;
    final isDark =
        ThemeData.estimateBrightnessForColor(coverColor) == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final spineColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.12),
      coverColor,
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 스프링 바인딩 척추
              Container(
                width: 22,
                color: spineColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5,
                    (_) => Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 표지 본체
              Expanded(
                child: Container(
                  color: coverColor,
                  padding: const EdgeInsets.fromLTRB(12, 16, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 줄 장식
                      Container(
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.35),
                        margin: const EdgeInsets.only(bottom: 12),
                      ),
                      // 책 아이콘
                      Icon(
                        Icons.water_drop_outlined,
                        size: 22,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                      const Spacer(),
                      // 공책 이름
                      Text(
                        book.name,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count개',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: textColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
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
