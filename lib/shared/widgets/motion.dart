import 'package:flutter/material.dart';

/// 앱 전체에서 같은 "쫀득한" 느낌을 내기 위한 곡선 모음.
abstract class AppMotion {
  /// 목표 지점을 살짝 지나쳤다가 들어오는 곡선 (하단 바 캡슐 이동과 같은 느낌)
  static const springy = Cubic(0.2, 0.9, 0.3, 1.04);

  /// 빠르게 출발해서 부드럽게 멈추는 곡선 (스크롤·페이지 넘김)
  static const smooth = Curves.easeOutCubic;
}

/// 켜질 때 "톡" 튀어 오르는 아이콘 — 좋아요 하트처럼 상태가 바뀌는 아이콘용.
/// [active]가 false → true로 바뀌는 순간에만 튀고, 꺼질 때는 부드럽게 바뀐다.
class PopIcon extends StatefulWidget {
  const PopIcon({
    super.key,
    required this.icon,
    required this.active,
    this.size,
    this.color,
  });

  final IconData icon;
  final bool active;
  final double? size;
  final Color? color;

  @override
  State<PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<PopIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.32)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.32, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 70,
    ),
  ]).animate(_ctrl);

  @override
  void didUpdateWidget(PopIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Icon(
          widget.icon,
          key: ValueKey(widget.icon),
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

/// 나타날 때 작게 시작해 살짝 튀며 커지고, 사라질 때 줄어들며 흐려진다.
/// "맨 위로" 같은 떠 있는 버튼용.
class PopReveal extends StatelessWidget {
  const PopReveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.6,
      duration: Duration(milliseconds: visible ? 360 : 200),
      curve: visible ? Curves.easeOutBack : Curves.easeIn,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }
}
