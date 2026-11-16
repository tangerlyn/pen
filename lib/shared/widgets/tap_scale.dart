import 'package:flutter/material.dart';

class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        // 놓을 때: 원래 크기를 살짝 넘었다가(1.0 위) 제자리로 — 쫀득한 복귀.
        // (역방향 재생이라 easeInBack을 쓰면 끝부분에서 0 아래로 내려갔다 돌아온다)
        reverseCurve: Curves.easeInBack,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _ctrl.forward();
  void _up(TapUpDetails _) {
    // 아주 짧게 톡 눌러도 눌린 느낌이 보이도록, 줄어드는 동작을 끝낸 뒤 복귀한다.
    if (_ctrl.status == AnimationStatus.forward) {
      _ctrl.forward().whenCompleteOrCancel(() {
        if (mounted) _ctrl.reverse();
      });
    } else {
      _ctrl.reverse();
    }
    widget.onTap?.call();
  }
  void _cancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? _down : null,
      onTapUp: widget.onTap != null ? _up : null,
      onTapCancel: widget.onTap != null ? _cancel : null,
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}
