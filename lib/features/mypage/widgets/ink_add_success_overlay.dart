import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 등록 완료 연출 — 원래 잉크 스와치 등록(차트 기록) 전용이었던 걸 일반화해서
/// 아카이브에 잉크/만년필을 새로 등록했을 때도 동일한 모션으로 재사용한다.
/// [visual]은 상단에 뜨는 170x170 비주얼(사진/색상 원 등)로, 그림자 등 자체
/// 스타일은 호출부에서 책임진다.
Future<void> showAddSuccessOverlay(
  BuildContext context, {
  required Widget visual,
  required String title,
  required String subtitle,
  required String caption,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, anim, secondAnim) => _AddSuccessOverlay(
      visual: visual,
      title: title,
      subtitle: subtitle,
      caption: caption,
    ),
  );
}

class _AddSuccessOverlay extends StatefulWidget {
  const _AddSuccessOverlay({
    required this.visual,
    required this.title,
    required this.subtitle,
    required this.caption,
  });

  final Widget visual;
  final String title;
  final String subtitle;
  final String caption;

  @override
  State<_AddSuccessOverlay> createState() => _AddSuccessOverlayState();
}

class _AddSuccessOverlayState extends State<_AddSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _swatchCtrl;
  late final AnimationController _rippleCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _exitCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _swatchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _runSequence();
  }

  Future<void> _runSequence() async {
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    _swatchCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _rippleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 420));
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1100));
    await _exitCtrl.forward();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _swatchCtrl.dispose();
    _rippleCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Widget _rippleRing(double progress, double delay, double maxRadius) {
    final p = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    final size = maxRadius * 2 * p;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: (1.0 - p) * 0.14),
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bgCtrl,
        _swatchCtrl,
        _rippleCtrl,
        _textCtrl,
        _exitCtrl,
      ]),
      builder: (context, _) {
        final bgAlpha = CurvedAnimation(
          parent: _bgCtrl,
          curve: Curves.easeOut,
        ).value;
        final swatchScale = CurvedAnimation(
          parent: _swatchCtrl,
          curve: Curves.elasticOut,
        ).value;
        final swatchRotate = Tween<double>(begin: -0.06, end: 0.0).evaluate(
          CurvedAnimation(parent: _swatchCtrl, curve: Curves.easeOutCubic),
        );
        final ripple = CurvedAnimation(
          parent: _rippleCtrl,
          curve: Curves.easeOut,
        ).value;
        final textDy = Tween<double>(begin: 20.0, end: 0.0).evaluate(
          CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
        );
        final textAlpha = CurvedAnimation(
          parent: _textCtrl,
          curve: Curves.easeOut,
        ).value;
        final exitAlpha =
            1.0 -
            CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn).value;

        return Opacity(
          opacity: exitAlpha,
          child: Material(
            color: Colors.white.withValues(alpha: bgAlpha),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _rippleRing(ripple, 0.00, 114),
                          _rippleRing(ripple, 0.14, 100),
                          _rippleRing(ripple, 0.28, 86),
                          Transform.rotate(
                            angle: swatchRotate,
                            child: Transform.scale(
                              scale: swatchScale,
                              child: SizedBox(
                                width: 170,
                                height: 170,
                                child: widget.visual,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Transform.translate(
                      offset: Offset(0, textDy),
                      child: Opacity(
                        opacity: textAlpha,
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              style: AppTextStyles.labelMedium.copyWith(
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontFamily: 'Pretendard',
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.caption,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
