import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/ink_swatch_shape.dart';

class InkCropScreen extends StatefulWidget {
  const InkCropScreen(
      {super.key, required this.imageFile, required this.shape});
  final File imageFile;
  final InkSwatchShape shape;

  @override
  State<InkCropScreen> createState() => _InkCropScreenState();
}

class _InkCropScreenState extends State<InkCropScreen> {
  static const _outputSize = 500.0;

  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  bool _isSaving = false;

  final _imageKey = GlobalKey();

  void _onScaleStart(ScaleStartDetails details) {
    _previousScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_previousScale * details.scale).clamp(0.5, 5.0);
      _offset += details.focalPointDelta;
    });
  }

  Future<void> _confirmCrop() async {
    setState(() => _isSaving = true);
    try {
      const pixelRatio = 3.0;
      final boundary =
          _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final captured = await boundary.toImage(pixelRatio: pixelRatio);

      final W = captured.width.toDouble();
      final H = captured.height.toDouble();
      final cs = math.min(W, H);
      final srcLeft = (W - cs) / 2;
      final srcTop = (H - cs) / 2;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, _outputSize, _outputSize));
      canvas.drawImageRect(
        captured,
        Rect.fromLTWH(srcLeft.toDouble(), srcTop.toDouble(), cs.toDouble(), cs.toDouble()),
        Rect.fromLTWH(0, 0, _outputSize, _outputSize),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final rendered =
          await picture.toImage(_outputSize.toInt(), _outputSize.toInt());
      final byteData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = widget.imageFile.parent.path;
      final outPath =
          '$dir/cropped_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(bytes);

      if (mounted) Navigator.of(context).pop(outFile);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title:
            const Text('사진 맞추기', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _confirmCrop,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('완료',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 이미지: 전체 화면 fill + Transform 으로 핀치줌/드래그
            RepaintBoundary(
              key: _imageKey,
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(_offset.dx, _offset.dy)
                  ..scale(_scale),
                alignment: Alignment.center,
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            // 모양 오버레이: 바깥 어둡게, 안쪽 투명
            IgnorePointer(
              child: CustomPaint(
                painter: _OverlayPainter(widget.shape),
              ),
            ),
            // 안내 텍스트
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                '두 손가락으로 확대/축소, 드래그로 위치 조정',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 전체 화면을 어둡게 칠한 뒤 모양 영역만 투명하게 뚫어줌
class _OverlayPainter extends CustomPainter {
  const _OverlayPainter(this.shape);
  final InkSwatchShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = math.min(size.width, size.height);
    final left = (size.width - cs) / 2;
    final top = (size.height - cs) / 2;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xAA000000));
    final path =
        getShapePath(shape, Size(cs, cs)).shift(Offset(left, top));
    canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.shape != shape;
}
