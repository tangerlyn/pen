import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 글래스모피즘 카드 공통 위젯.
///
/// [useBlur] = true 일 때만 BackdropFilter 적용.
/// 리스트/그리드 카드처럼 다수가 동시에 렌더링되는 경우 false 권장.
/// 모달·바텀시트·앱바 오버레이처럼 단독으로 뜨는 경우 true.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.lg,
    this.padding,
    this.margin,
    this.opacity = 0.78,
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
    final inner = Material(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: br,
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
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x08FFFFFF),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: useBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
