import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';

/// 공책 페이지 배경 스타일. Firestore의 InkBookModel.pageStyle과 1:1 대응.
enum NotebookPageStyle { lines, grid, plain }

NotebookPageStyle notebookPageStyleFromString(String value) => NotebookPageStyle
    .values
    .firstWhere((v) => v.name == value, orElse: () => NotebookPageStyle.lines);

/// 공책 한 페이지(3×3 그리드 + 종이 배경)를 렌더링하는 공용 위젯.
/// 소유자의 편집 화면과 다른 유저용 읽기 전용 화면이 동일한 코드로
/// 똑같은 모양을 그리도록 공유한다.
class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.pageEntries,
    required this.pageStyle,
    required this.itemBuilder,
  });

  /// 이 페이지에 들어갈 항목(최대 [itemsPerPage]개). 부족한 칸은 빈 슬롯으로 채워진다.
  final List<InkChartModel> pageEntries;
  final NotebookPageStyle pageStyle;
  final Widget Function(
    BuildContext context,
    InkChartModel entry,
    int indexInPage,
  )
  itemBuilder;

  static const itemsPerPage = 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 10,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: NotebookLinePainter(pageStyle),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageStyle == NotebookPageStyle.lines) const _LeftMargin(),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    pageStyle == NotebookPageStyle.lines ? 56 : 16,
                    8,
                    8,
                  ),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: itemsPerPage,
                  itemBuilder: (ctx, i) {
                    if (i < pageEntries.length) {
                      return itemBuilder(ctx, pageEntries[i], i);
                    }
                    return const _EmptySlot();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 노트 왼쪽 여백 ──────────────────────────────────────────────────────────

class _LeftMargin extends StatelessWidget {
  const _LeftMargin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCCCCCC)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 노트 줄 배경 CustomPainter ────────────────────────────────────────────

class NotebookLinePainter extends CustomPainter {
  const NotebookLinePainter(this.style);
  final NotebookPageStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == NotebookPageStyle.plain) return;

    final linePaint = Paint()
      ..color = const Color(0xFFD0DCF0).withValues(alpha: 0.7)
      ..strokeWidth = 0.6;

    if (style == NotebookPageStyle.lines) {
      final redPaint = Paint()
        ..color = const Color(0xFFE8A0A0)
        ..strokeWidth = 1.8;
      canvas.drawLine(const Offset(30, 48), Offset(size.width, 48), redPaint);
      canvas.drawLine(const Offset(30, 0), Offset(30, size.height), redPaint);
      for (double y = 76; y < size.height - 8; y += 26) {
        canvas.drawLine(Offset(38, y), Offset(size.width - 6, y), linePaint);
      }
    } else {
      // grid: 빨간 줄 없음, 격자만
      for (double y = 26; y < size.height - 8; y += 26) {
        canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), linePaint);
      }
      for (double x = 32; x < size.width - 6; x += 26) {
        canvas.drawLine(Offset(x, 6), Offset(x, size.height - 8), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NotebookLinePainter old) => old.style != style;
}

// ── 빈 슬롯 (점선 원) ──────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
            padding: EdgeInsets.all(6),
            child: CustomPaint(painter: _DashedCirclePainter()),
          ),
        ),
        SizedBox(height: 28),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4C5A9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const dashCount = 24;
    const dashAngle = 2 * math.pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        dashAngle * 0.65,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => false;
}
