import 'package:flutter/material.dart';
import '../../../data/models/pen_model.dart';
import '../../../core/theme/app_theme.dart';

class PenListTile extends StatelessWidget {
  const PenListTile({super.key, required this.pen, required this.onTap});
  final PenModel pen;
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
        ),
        child: const Icon(Icons.edit, color: AppColors.textSecondary),
      ),
      title: Text(pen.modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${pen.brand} · ${pen.nibMaterial} · ${pen.fillType}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              Text(pen.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text('리뷰 ${pen.reviewCount}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
