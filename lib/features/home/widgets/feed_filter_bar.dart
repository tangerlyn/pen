import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/feed_provider.dart';

class FeedFilterBar extends StatelessWidget {
  const FeedFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  final FeedFilter filter;
  final ValueChanged<FeedFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          // 카테고리 칩
          ...AppStrings.reviewFilterChips.map((cat) {
            final isSelected = filter.category == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.chipBackground,
                showCheckmark: false,
                onSelected: (_) => onFilterChanged(
                  filter.copyWith(category: cat, clearSub: true),
                ),
              ),
            );
          }),

        ],
      ),
    );
  }
}
