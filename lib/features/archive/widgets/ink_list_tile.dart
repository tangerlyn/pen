import 'package:flutter/material.dart';
import '../../../data/models/ink_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';

class InkListTile extends StatelessWidget {
  const InkListTile({super.key, required this.ink, required this.onTap});
  final InkModel ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: ListTile(
        leading: InkDropCircle(color: ink.inkColor, size: 44),
        title: Text(
          ink.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${ink.brand} · ${ink.autoColorFamily}'),
        // 별점 시스템 비활성화 — 평균 별점 표시 제거, 리뷰 개수만 표시
        // trailing: Column(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   crossAxisAlignment: CrossAxisAlignment.end,
        //   children: [
        //     Row(
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         const Icon(Icons.star, color: Colors.amber, size: 14),
        //         Text(
        //           ink.avgRating.toStringAsFixed(1),
        //           style: const TextStyle(fontSize: 12),
        //         ),
        //       ],
        //     ),
        //     Text(
        //       '리뷰 ${ink.reviewCount}',
        //       style: const TextStyle(
        //         fontSize: 11,
        //         color: AppColors.textSecondary,
        //       ),
        //     ),
        //   ],
        // ),
        trailing: Text(
          '리뷰 ${ink.reviewCount}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
