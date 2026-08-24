import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../data/models/pen_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tap_scale.dart';

class PenListTile extends StatelessWidget {
  const PenListTile({super.key, required this.pen, required this.onTap});
  final PenModel pen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: ListTile(
        leading: ClipOval(
          child: Container(
            width: 44,
            height: 44,
            color: AppColors.chipBackground,
            alignment: Alignment.center,
            child: (pen.photoUrl == null || pen.photoUrl!.isEmpty)
                ? const Icon(Icons.edit, color: AppColors.textSecondary)
                : CachedNetworkImage(
                    imageUrl: pen.photoUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.edit, color: AppColors.textSecondary),
                  ),
          ),
        ),
        title: Text(
          pen.modelName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${pen.brand} · ${pen.fillType}'),
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
        //           pen.avgRating.toStringAsFixed(1),
        //           style: const TextStyle(fontSize: 12),
        //         ),
        //       ],
        //     ),
        //     Text(
        //       '리뷰 ${pen.reviewCount}',
        //       style: const TextStyle(
        //         fontSize: 11,
        //         color: AppColors.textSecondary,
        //       ),
        //     ),
        //   ],
        // ),
        trailing: Text(
          '리뷰 ${pen.reviewCount}',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
