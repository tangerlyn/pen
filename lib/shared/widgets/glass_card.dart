import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 글래스모피즘 카드 공통 위젯.
///
/// [useBlur] = false (기본): ClipRRect 없이 Material clip만 사용 → 성능 최적.
/// [useBlur] = true: BackdropFilter blur 적용 — 모달/바텀시트 등 단독 요소에만 사용.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.lg,
    this.padding,
    this.margin,
    this.opacity = 0.82,
    this.onTap,
    this.useBlur = false,
    this.blur = AppGlass.blur,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double opacity;
  final VoidCallback? onTap;
  final bool useBlur;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);

    // 카드 본체 — Material이 borderRadius + clip 담당 (ClipRRect 없이)
    Widget card = Material(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );

    // blur 필요할 때만 ClipRRect + BackdropFilter 래핑
    if (useBlur) {
      card = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: card,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: AppShadows.cardMd,
      ),
      child: card,
    );
  }
}
