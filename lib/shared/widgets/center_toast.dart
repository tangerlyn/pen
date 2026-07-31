import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 화면 중앙에 잠깐 떴다 사라지는 알림 팝업.
/// 기존 SnackBar를 대체하는 공용 위젯 — 하단 스낵바 대신 시선이 잘 가는 중앙 팝업으로 안내.
Future<void> showCenterToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  Color? iconColor,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim, secondAnim) => _CenterToast(
      message: message,
      icon: icon,
      iconColor: iconColor,
    ),
    transitionBuilder: (ctx, anim, secondAnim, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _CenterToast extends StatefulWidget {
  const _CenterToast({required this.message, this.icon, this.iconColor});
  final String message;
  final IconData? icon;
  final Color? iconColor;

  @override
  State<_CenterToast> createState() => _CenterToastState();
}

class _CenterToastState extends State<_CenterToast> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      // 여러 토스트가 겹칠 때 위에 쌓인 다른 토스트를 잘못 닫지 않도록,
      // 최상단 route를 무조건 pop하지 않고 자기 자신의 route만 제거한다.
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.iconColor ?? AppColors.primary, size: 32),
                const SizedBox(height: 10),
              ],
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
