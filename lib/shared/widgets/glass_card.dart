import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 글래스모피즘 카드 공통 위젯.
/// shadow는 ClipRRect 바깥 Container에, blur는 BackdropFilter로 처리.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.lg,
    this.padding,
    this.margin,
    this.blur = AppGlass.blur,
    this.opacity = AppGlass.cardOpacity,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.white.withValues(alpha: opacity),
            child: InkWell(
              onTap: onTap,
              borderRadius: br,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
