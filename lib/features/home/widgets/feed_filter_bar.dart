import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/category_chip.dart';
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
              child: CategoryChip(
                label: cat,
                selected: isSelected,
                onTap: () => onFilterChanged(
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
