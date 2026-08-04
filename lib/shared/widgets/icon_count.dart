import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 좋아요/댓글 수 같은 "아이콘 + 숫자" 통계 표시용 공용 위젯.
class IconCount extends StatelessWidget {
  const IconCount({
    super.key,
    required this.icon,
    required this.count,
    this.iconSize = 14,
    this.color = AppColors.textTertiary,
    Color? iconColor,
    this.fontSize,
    this.spacing = 3,
  }) : iconColor = iconColor ?? color;

  final IconData icon;
  final int count;
  final double iconSize;
  final Color color;
  final Color iconColor;
  final double? fontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        SizedBox(width: spacing),
        Text(
          '$count',
          style: fontSize != null
              ? TextStyle(fontSize: fontSize, color: color)
              : AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}
