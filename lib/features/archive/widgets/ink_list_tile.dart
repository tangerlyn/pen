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
      leading: _InkGlassBall(color: ink.inkColor, size: 44),
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
}

class _InkGlassBall extends StatelessWidget {
  const _InkGlassBall({required this.color, this.size = 56});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final lighter = Color.lerp(color, Colors.white, 0.50)!;
    final darker  = Color.lerp(color, Colors.black, 0.18)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(1.5, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // ① 베이스 — 방사형 그라데이션으로 구형 입체감
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.35),
                  radius: 0.85,
                  colors: [lighter, color, darker],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            // ② 주 스페큘러 하이라이트 — 빤질빤질한 광택점
            Positioned(
              left: size * 0.16,
              top:  size * 0.11,
              child: Container(
                width:  size * 0.34,
                height: size * 0.24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // ③ 하단 반사광 — 유리 안쪽 빛 번짐
            Positioned(
              right:  size * 0.12,
              bottom: size * 0.10,
              child: Container(
                width:  size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
