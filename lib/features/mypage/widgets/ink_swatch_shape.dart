import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum InkSwatchShape {
  circle('원형', Icons.circle_outlined),
  bottle('잉크병', Icons.hexagon_outlined),
  brushStroke('붓터치', Icons.brush_outlined);

  const InkSwatchShape(this.label, this.icon);
  final String label;
  final IconData icon;
}

Path getShapePath(InkSwatchShape shape, Size size) {
  final w = size.width;
  final h = size.height;
  switch (shape) {
    case InkSwatchShape.circle:
      return Path()..addOval(Rect.fromLTWH(0, 0, w, h));

    case InkSwatchShape.bottle:
      final path = Path();
      final cx = w / 2;
      final r = math.min(w, h) * 0.46;
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60 - 90) * math.pi / 180;
        final px = cx + r * math.cos(angle);
        final py = h / 2 + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      return path;

    case InkSwatchShape.brushStroke:
      const svgW = 900.0;
      const svgH = 750.0;
      final sx = w / svgW;
      final sy = h / svgH;
      final path = Path();
      path.moveTo(542.5 * sx, 55 * sy);
      path.lineTo(558.5 * sx, 56 * sy);
      path.lineTo(569.5 * sx, 59 * sy);
      path.quadraticBezierTo(582.8 * sx, 64.8 * sy, 591 * sx, 75.5 * sy);
      path.quadraticBezierTo(600.4 * sx, 87 * sy, 605 * sx, 103.5 * sy);
      path.lineTo(606 * sx, 122.5 * sy);
      path.quadraticBezierTo(601.8 * sx, 141.8 * sy, 594 * sx, 157.5 * sy);
      path.lineTo(562 * sx, 219.5 * sy);
      path.lineTo(564.5 * sx, 218 * sy);
      path.lineTo(581.5 * sx, 208 * sy);
      path.lineTo(602.5 * sx, 201 * sy);
      path.lineTo(617.5 * sx, 198 * sy);
      path.lineTo(640.5 * sx, 198 * sy);
      path.lineTo(641.5 * sx, 199 * sy);
      path.lineTo(660.5 * sx, 199 * sy);
      path.lineTo(673.5 * sx, 203 * sy);
      path.quadraticBezierTo(690.4 * sx, 211.6 * sy, 702 * sx, 225.5 * sy);
      path.lineTo(715 * sx, 246.5 * sy);
      path.lineTo(718 * sx, 260.5 * sy);
      path.lineTo(718 * sx, 273.5 * sy);
      path.lineTo(717 * sx, 274.5 * sy);
      path.lineTo(717 * sx, 282.5 * sy);
      path.lineTo(715 * sx, 292.5 * sy);
      path.lineTo(710 * sx, 308.5 * sy);
      path.quadraticBezierTo(702.1 * sx, 326.1 * sy, 690 * sx, 339.5 * sy);
      path.lineTo(687 * sx, 350 * sy);
      path.lineTo(706.5 * sx, 348 * sy);
      path.lineTo(707.5 * sx, 349 * sy);
      path.lineTo(727.5 * sx, 350 * sy);
      path.lineTo(759.5 * sx, 358 * sy);
      path.lineTo(779.5 * sx, 367 * sy);
      path.lineTo(794 * sx, 379.5 * sy);
      path.quadraticBezierTo(801.6 * sx, 389.4 * sy, 805 * sx, 403.5 * sy);
      path.lineTo(807 * sx, 421.5 * sy);
      path.lineTo(808 * sx, 422.5 * sy);
      path.lineTo(808 * sx, 447.5 * sy);
      path.quadraticBezierTo(796.2 * sx, 503.7 * sy, 770 * sx, 545.5 * sy);
      path.quadraticBezierTo(734.7 * sx, 605.2 * sy, 696 * sx, 661.5 * sy);
      path.lineTo(661 * sx, 710.5 * sy);
      path.lineTo(647.5 * sx, 726 * sy);
      path.quadraticBezierTo(636.9 * sx, 735.4 * sy, 621.5 * sx, 740 * sy);
      path.lineTo(612.5 * sx, 742 * sy);
      path.lineTo(594.5 * sx, 742 * sy);
      path.quadraticBezierTo(567.8 * sx, 737.2 * sy, 553 * sx, 720.5 * sy);
      path.quadraticBezierTo(543.2 * sx, 710.3 * sy, 538 * sx, 695.5 * sy);
      path.lineTo(535 * sx, 679.5 * sy);
      path.lineTo(535 * sx, 669.5 * sy);
      path.lineTo(536 * sx, 668.5 * sy);
      path.lineTo(537 * sx, 657.5 * sy);
      path.lineTo(541 * sx, 646.5 * sy);
      path.lineTo(538.5 * sx, 648 * sy);
      path.lineTo(500.5 * sx, 680 * sy);
      path.lineTo(463.5 * sx, 704 * sy);
      path.quadraticBezierTo(452 * sx, 711 * sy, 437.5 * sx, 715 * sy);
      path.lineTo(426.5 * sx, 716 * sy);
      path.lineTo(425.5 * sx, 717 * sy);
      path.lineTo(403.5 * sx, 718 * sy);
      path.lineTo(402.5 * sx, 717 * sy);
      path.lineTo(391.5 * sx, 717 * sy);
      path.lineTo(376.5 * sx, 713 * sy);
      path.quadraticBezierTo(363 * sx, 707.5 * sy, 355 * sx, 696.5 * sy);
      path.quadraticBezierTo(337.3 * sx, 675.7 * sy, 335 * sx, 639.5 * sy);
      path.lineTo(336 * sx, 637 * sy);
      path.lineTo(331.5 * sx, 639 * sy);
      path.lineTo(286.5 * sx, 676 * sy);
      path.lineTo(247.5 * sx, 702 * sy);
      path.lineTo(222.5 * sx, 715 * sy);
      path.lineTo(217.5 * sx, 716 * sy);
      path.quadraticBezierTo(211.1 * sx, 723.6 * sy, 201.5 * sx, 728 * sy);
      path.lineTo(186.5 * sx, 733 * sy);
      path.lineTo(171.5 * sx, 734 * sy);
      path.lineTo(170.5 * sx, 733 * sy);
      path.lineTo(158.5 * sx, 732 * sy);
      path.lineTo(141.5 * sx, 725 * sy);
      path.lineTo(124 * sx, 709.5 * sy);
      path.quadraticBezierTo(116.8 * sx, 700.7 * sy, 113 * sx, 688.5 * sy);
      path.lineTo(111 * sx, 679.5 * sy);
      path.lineTo(111 * sx, 661.5 * sy);
      path.lineTo(115 * sx, 646.5 * sy);
      path.lineTo(125 * sx, 629.5 * sy);
      path.lineTo(207 * sx, 522.5 * sy);
      path.lineTo(255 * sx, 453.5 * sy);
      path.lineTo(253.5 * sx, 453 * sy);
      path.quadraticBezierTo(217.6 * sx, 477.6 * sy, 177.5 * sx, 498 * sy);
      path.lineTo(164.5 * sx, 503 * sy);
      path.lineTo(141.5 * sx, 504 * sy);
      path.lineTo(140.5 * sx, 503 * sy);
      path.lineTo(132.5 * sx, 503 * sy);
      path.lineTo(116.5 * sx, 497 * sy);
      path.lineTo(100 * sx, 484.5 * sy);
      path.lineTo(93 * sx, 476.5 * sy);
      path.lineTo(84 * sx, 460.5 * sy);
      path.lineTo(81 * sx, 448.5 * sy);
      path.lineTo(81 * sx, 425.5 * sy);
      path.quadraticBezierTo(86.6 * sx, 398.6 * sy, 104.5 * sx, 384 * sy);
      path.lineTo(109 * sx, 382 * sy);
      path.lineTo(166 * sx, 306.5 * sy);
      path.lineTo(164.5 * sx, 307 * sy);
      path.lineTo(151.5 * sx, 308 * sy);
      path.lineTo(150.5 * sx, 307 * sy);
      path.lineTo(138.5 * sx, 306 * sy);
      path.lineTo(125.5 * sx, 301 * sy);
      path.quadraticBezierTo(113.3 * sx, 294.1 * sy, 105 * sx, 283.5 * sy);
      path.lineTo(98 * sx, 271.5 * sy);
      path.lineTo(95 * sx, 262.5 * sy);
      path.lineTo(94 * sx, 248.5 * sy);
      path.lineTo(93 * sx, 247.5 * sy);
      path.lineTo(94 * sx, 246.5 * sy);
      path.lineTo(94 * sx, 237.5 * sy);
      path.lineTo(96 * sx, 229.5 * sy);
      path.lineTo(102 * sx, 216.5 * sy);
      path.lineTo(117.5 * sx, 199 * sy);
      path.lineTo(192.5 * sx, 137 * sy);
      path.lineTo(216.5 * sx, 120 * sy);
      path.lineTo(262.5 * sx, 96 * sy);
      path.quadraticBezierTo(272.9 * sx, 91.9 * sy, 287.5 * sx, 92 * sy);
      path.lineTo(304.5 * sx, 95 * sy);
      path.lineTo(324.5 * sx, 102 * sy);
      path.quadraticBezierTo(348.5 * sx, 111.5 * sy, 364 * sx, 129.5 * sy);
      path.lineTo(369 * sx, 141 * sy);
      path.lineTo(372.5 * sx, 140 * sy);
      path.quadraticBezierTo(403.5 * sx, 113.5 * sy, 438.5 * sx, 91 * sy);
      path.lineTo(471.5 * sx, 73 * sy);
      path.lineTo(501.5 * sx, 62 * sy);
      path.lineTo(517.5 * sx, 58 * sy);
      path.lineTo(522.5 * sx, 58 * sy);
      path.lineTo(529.5 * sx, 56 * sy);
      path.lineTo(541.5 * sx, 56 * sy);
      path.lineTo(542.5 * sx, 55 * sy);
      path.close();
      return path;
  }
}

// PNG mask 이미지 1회 로드 및 캐싱
class BottleMask {
  static ui.Image? _cached;
  static Future<ui.Image>? _future;

  /// 이미 로드돼 캐싱된 이미지가 있으면 즉시 반환(동기), 없으면 null
  static ui.Image? get cached => _cached;

  static Future<ui.Image> load() {
    return _future ??= _doLoad().then((img) {
      _cached = img;
      return img;
    });
  }

  static Future<ui.Image> _doLoad() async {
    final data = await rootBundle.load('assets/shapes/ink_jar.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// circle/brushStroke은 Path 클리핑, bottle은 PNG ShaderMask로 처리
class InkShapeClip extends StatefulWidget {
  const InkShapeClip({super.key, required this.shape, required this.child});
  final InkSwatchShape shape;
  final Widget child;

  @override
  State<InkShapeClip> createState() => _InkShapeClipState();
}

class _InkShapeClipState extends State<InkShapeClip> {
  ui.Image? _maskImage;

  @override
  void initState() {
    super.initState();
    debugPrint('[InkShapeClip] shape: ${widget.shape}');
    if (widget.shape == InkSwatchShape.bottle) {
      _maskImage = BottleMask._cached;
      debugPrint('[InkShapeClip] cached image: $_maskImage');
      if (_maskImage == null) {
        BottleMask.load().then((img) {
          debugPrint('[InkShapeClip] image loaded: ${img.width}x${img.height}');
          if (mounted) setState(() => _maskImage = img);
        }).catchError((e) {
          debugPrint('[InkShapeClip] load error: $e');
        });
      }
    }
  }

  @override
  void didUpdateWidget(InkShapeClip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shape == InkSwatchShape.bottle && _maskImage == null) {
      _maskImage = BottleMask._cached;
      if (_maskImage == null) {
        BottleMask.load().then((img) {
          if (mounted) setState(() => _maskImage = img);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[InkShapeClip] build - shape: ${widget.shape}, maskImage: $_maskImage');
    if (widget.shape != InkSwatchShape.bottle) {
      return ClipPath(clipper: InkShapeClipper(widget.shape), child: widget.child);
    }
    if (_maskImage == null) return widget.child;
    final img = _maskImage!;
    return ShaderMask(
      shaderCallback: (bounds) => ui.ImageShader(
        img,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.diagonal3Values(
          bounds.width / img.width,
          bounds.height / img.height,
          1.0,
        ).storage,
      ),
      blendMode: BlendMode.dstIn,
      child: widget.child,
    );
  }
}

class InkShapeClipper extends CustomClipper<Path> {
  const InkShapeClipper(this.shape);
  final InkSwatchShape shape;

  @override
  Path getClip(Size size) => getShapePath(shape, size);

  @override
  bool shouldReclip(InkShapeClipper old) => old.shape != shape;
}

// Dims everything outside the shape (used on crop screen)
class ShapeOverlayPainter extends CustomPainter {
  const ShapeOverlayPainter(this.shape, {this.dimColor = const Color(0x99000000)});
  final InkSwatchShape shape;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = dimColor);
    canvas.drawPath(
      getShapePath(shape, size),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShapeOverlayPainter old) =>
      old.shape != shape || old.dimColor != dimColor;
}

// Fills shape with a solid color (used in shape picker preview)
class ShapePreviewPainter extends CustomPainter {
  const ShapePreviewPainter(this.shape, this.color);
  final InkSwatchShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(getShapePath(shape, size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(ShapePreviewPainter old) =>
      old.shape != shape || old.color != color;
}
