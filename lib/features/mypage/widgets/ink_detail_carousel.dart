import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tap_scale.dart';

/// 잉크 스와치 상세 정보를 좌우로 넘겨볼 수 있는 캐러셀 셸(핸들/카운터/좌우 화살표).
/// 소유자용 편집 화면과 읽기 전용 화면이 동일한 틀을 공유하고, 각 페이지의
/// 실제 내용([pageBuilder])만 다르게 넣는다.
class InkDetailCarousel extends StatefulWidget {
  const InkDetailCarousel({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.pageBuilder,
  });

  final int itemCount;
  final int initialIndex;
  final Widget Function(BuildContext context, int index) pageBuilder;

  @override
  State<InkDetailCarousel> createState() => _InkDetailCarouselState();
}

class _InkDetailCarouselState extends State<InkDetailCarousel> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE4D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_currentIndex + 1} / ${widget.itemCount}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(builder: (ctx) {
              final imgH = MediaQuery.of(ctx).size.width * 0.68;
              const imgTop = 20.0;
              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: widget.itemCount,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: widget.pageBuilder,
                  ),
                  if (_currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: imgTop,
                      height: imgH,
                      child: Center(
                        child: InkDetailNavButton(
                          icon: Icons.chevron_left,
                          onPressed: () => _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                  if (_currentIndex < widget.itemCount - 1)
                    Positioned(
                      right: 8,
                      top: imgTop,
                      height: imgH,
                      child: Center(
                        child: InkDetailNavButton(
                          icon: Icons.chevron_right,
                          onPressed: () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── 화살표 버튼 ───────────────────────────────────────────────────────────

class InkDetailNavButton extends StatelessWidget {
  const InkDetailNavButton({super.key, required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      ),
    );
  }
}
