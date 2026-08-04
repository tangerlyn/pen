import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 게시글/리뷰 작성자가 자신의 글에 직접 남긴 댓글·답글 옆에 붙는 "작성자" 뱃지.
class AuthorBadge extends StatelessWidget {
  const AuthorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '작성자',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
