import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/level_system.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        LevelSystem.shortLabel(level),
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
