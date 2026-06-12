import 'package:flutter/material.dart';

/// 만년필 잉크가 종이에 스며든 느낌의 원형 위젯.
///
/// 만년필 잉크 'shading'의 시각적 특성:
///   - 가장자리가 더 진함: 잉크가 경계에 고임 (pooling / shading)
///   - 중심이 살짝 옅음: 잉크가 퍼지면서 중심부 희석
///   - 무광(matte): 광택 없음
///   - 자연스러운 밀도 변화: 잉크가 고르지 않게 번진 유기적 질감
class InkDropCircle extends StatelessWidget {
  const InkDropCircle({super.key, required this.color, this.size = 56});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final diluted = Color.lerp(color, Colors.white, 0.22)!; // 중심 희석
    final shaded  = Color.lerp(color, Colors.black, 0.34)!; // 가장자리 shading
    final pooled  = Color.lerp(color, Colors.black, 0.18)!; // 농도 클러스터

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // 잉크가 종이에 스며드는 착색 그림자
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // ① shading 베이스 — 만년필 잉크의 핵심 특성
            //    중심이 옅고 → 가장자리로 갈수록 진해짐
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.06, 0.06),
                  radius: 0.88,
                  colors: [diluted, color, shaded],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
            // ② 번짐 변화 — 잉크 밀도가 고르지 않은 자연스러운 변화
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.30, -0.38),
                  radius: 0.52,
                  colors: [
                    Colors.white.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // ③ 잉크 고임 — 우하단에 잉크가 살짝 모인 농도 클러스터
            Positioned(
              right: size * 0.13,
              bottom: size * 0.10,
              child: Container(
                width:  size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      pooled.withValues(alpha: 0.38),
                      pooled.withValues(alpha: 0.0),
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
