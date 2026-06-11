import 'package:flutter/material.dart';
import '../../../data/models/paper_model.dart';
import '../../../core/theme/app_theme.dart';

class PaperListTile extends StatelessWidget {
  const PaperListTile({super.key, required this.paper, required this.onTap});
  final PaperModel paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Icon(Icons.article_outlined, color: AppColors.textSecondary),
      ),
      title: Text(paper.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${paper.brand} · ${paper.rulingType} · ${paper.grammage}g'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              Text(paper.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text('리뷰 ${paper.reviewCount}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
