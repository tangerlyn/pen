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
    this.menuBuilder,
  });

  final int itemCount;
  final int initialIndex;
  final Widget Function(BuildContext context, int index) pageBuilder;

  /// 우측 상단 ⋮ 메뉴(수정/삭제 등) — 소유자 화면에서만 전달, 읽기 전용
  /// 화면은 null로 둬서 메뉴 자체가 안 보이게 함
  final Widget Function(BuildContext context, int index)? menuBuilder;

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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.itemCount}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (widget.menuBuilder != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.menuBuilder!(context, _currentIndex),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (ctx) {
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 화살표 버튼 ───────────────────────────────────────────────────────────

class InkDetailNavButton extends StatelessWidget {
  const InkDetailNavButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });
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
