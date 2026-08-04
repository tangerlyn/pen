import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'ink_swatch_shape.dart';

Future<void> showInkAddSuccess(
  BuildContext context, {
  required File photo,
  required InkSwatchShape shape,
  required String brand,
  required String inkName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, anim, secondAnim) => _InkAddSuccessOverlay(
      photo: photo,
      shape: shape,
      brand: brand,
      inkName: inkName,
    ),
  );
}

class _InkAddSuccessOverlay extends StatefulWidget {
  const _InkAddSuccessOverlay({
    required this.photo,
    required this.shape,
    required this.brand,
    required this.inkName,
  });

  final File photo;
  final InkSwatchShape shape;
  final String brand;
  final String inkName;

  @override
  State<_InkAddSuccessOverlay> createState() => _InkAddSuccessOverlayState();
}

class _InkAddSuccessOverlayState extends State<_InkAddSuccessOverlay>
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
                              child: Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: InkShapeClip(
                                  shape: widget.shape,
                                  child: Image.file(
                                    widget.photo,
                                    fit: BoxFit.cover,
                                  ),
                                ),
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
                              widget.brand,
                              style: AppTextStyles.labelMedium.copyWith(
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.inkName,
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
                              '차트에 기록됐어요',
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
