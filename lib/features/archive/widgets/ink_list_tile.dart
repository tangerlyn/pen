import 'package:flutter/material.dart';
import '../../../data/models/ink_model.dart';
import '../../../core/theme/app_theme.dart';

class InkListTile extends StatelessWidget {
  const InkListTile({super.key, required this.ink, required this.onTap});
  final InkModel ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _parseHexColor(ink.hexColor),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
      ),
      title: Text(ink.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${ink.brand} · ${ink.autoColorFamily}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              Text(ink.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text('리뷰 ${ink.reviewCount}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Color _parseHexColor(String hex) {
    if (hex.isEmpty) return Colors.grey.shade300;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey.shade300;
    }
  }
}
