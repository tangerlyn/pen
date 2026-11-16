import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/banner_model.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../providers/home_discovery_provider.dart';

/// 홈 맨 위 배너. 여러 개면 좌우로 넘기고 5초마다 자동으로 넘어가며,
/// 오른쪽 아래에 "1 / 3" 페이지 표시가 붙는다. 누르면 배너 상세 화면으로 간다.
class HomeBannerCarousel extends ConsumerStatefulWidget {
  const HomeBannerCarousel({super.key});

  /// 카드 높이 — 기본은 가로:세로 2:1. 글자를 키운 기기에서는
  /// 꼬리표 + 제목 두 줄 + 부제 한 줄이 잘리지 않도록 더 늘어난다.
  static double cardHeight(BuildContext context, double cardWidth) {
    final s = MediaQuery.textScalerOf(context).scale(1);
    // 세로 여백 36 + 꼬리표·간격 (20s + 8) + 제목 2줄 (19 × 1.3 × 2 × s)
    // + 간격 6 + 부제 (12.5 × 1.4 × s) + 여유 4
    final content = 36 + 8 + 6 + 4 + (20 + 49.4 + 17.5) * s;
    return cardWidth / 2 > content ? cardWidth / 2 : content;
  }

  @override
  ConsumerState<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends ConsumerState<HomeBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _count = 0;
  int _page = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartAutoSlide() {
    _timer?.cancel();
    if (_count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _count,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(homeBannersProvider).valueOrNull;
    final cardWidth = MediaQuery.sizeOf(context).width - AppSpacing.lg * 2;
    final height = HomeBannerCarousel.cardHeight(context, cardWidth);

    if (banners == null || banners.isEmpty) {
      // 로딩 중에도 자리를 잡아 둬서 아래 섹션이 튀지 않게 한다.
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }

    if (banners.length != _count) {
      _count = banners.length;
      if (_page >= _count) _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartAutoSlide();
      });
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                // 사용자가 직접 넘기면 자동 넘김 타이머를 처음부터 다시 잰다.
                if (n.dragDetails != null) _restartAutoSlide();
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: HomeBannerCard(
                    banner: banners[i],
                    onTap: () => context.push(
                      '/banner/${banners[i].id}',
                      extra: banners[i],
                    ),
                  ),
                ),
              ),
            ),
            if (banners.length > 1)
              Positioned(
                right: AppSpacing.lg + 10,
                bottom: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${_page + 1} / ${banners.length}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _parseHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final v = int.tryParse(hex.replaceAll('#', ''), radix: 16);
  if (v == null) return fallback;
  return hex.replaceAll('#', '').length <= 6 ? Color(0xFF000000 | v) : Color(v);
}

/// 배너 카드 한 장.
/// - 이미지 배너: 이미지 위 아래쪽을 어둡게 하고 흰 글씨
/// - 이미지 없는 배너: 단색 배경 + 네이비 글씨 (글자 중심)
class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({super.key, required this.banner, this.onTap});

  static const defaultBackground = Color(0xFFEDE7DA);

  final BannerModel banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageUrl != null;
    final bg = _parseHex(banner.backgroundColor, defaultBackground);
    final fg = hasImage ? Colors.white : AppColors.primary;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: bg),
          if (hasImage) ...[
            CachedNetworkImage(
              imageUrl: banner.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: bg),
              errorWidget: (_, _, _) => ColoredBox(color: bg),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Color(0x00000000), Color(0x8C000000)],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisAlignment:
                  hasImage ? MainAxisAlignment.end : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (banner.label != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: hasImage
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      banner.label!,
                      maxLines: 1,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: hasImage ? AppColors.primary : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  banner.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: fg,
                  ),
                ),
                if (banner.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: fg.withValues(alpha: hasImage ? 0.9 : 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return TapScale(onTap: onTap, scale: 0.98, child: card);
  }
}
