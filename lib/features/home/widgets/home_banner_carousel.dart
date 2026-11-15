import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/banner_model.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../providers/home_discovery_provider.dart';

/// 홈 맨 위 배너. 여러 개면 좌우로 넘기고 5초마다 자동으로 넘어간다.
/// 누르면 배너 상세 화면으로 간다.
class HomeBannerCarousel extends ConsumerStatefulWidget {
  const HomeBannerCarousel({super.key});

  /// 배너 가로:세로 비율. 글자 크기 1.3배에서도 제목 1줄 + 부제 2줄이 들어간다.
  static const aspectRatio = 2.4;

  @override
  ConsumerState<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends ConsumerState<HomeBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _count = 0;

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
      final next = ((_controller.page ?? 0).round() + 1) % _count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(homeBannersProvider).valueOrNull;
    if (banners == null || banners.isEmpty) {
      // 로딩 중에도 자리를 잡아 둬서 아래 섹션이 튀지 않게 한다.
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
        ),
        child: AspectRatio(
          aspectRatio: HomeBannerCarousel.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      );
    }

    if (banners.length != _count) {
      _count = banners.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartAutoSlide();
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.md),
      child: Column(
        children: [
          AspectRatio(
            // 좌우 여백(16+16)을 뺀 카드 폭 기준 비율을 화면 폭 기준으로 환산
            aspectRatio: HomeBannerCarousel.aspectRatio *
                MediaQuery.sizeOf(context).width /
                (MediaQuery.sizeOf(context).width - AppSpacing.lg * 2),
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                // 사용자가 직접 넘기면 자동 넘김 타이머를 처음부터 다시 잰다.
                if (n.dragDetails != null) _restartAutoSlide();
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
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
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SmoothPageIndicator(
              controller: _controller,
              count: banners.length,
              effect: const ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                spacing: 4,
                activeDotColor: AppColors.primary,
                dotColor: AppColors.divider,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 배너 카드 한 장. 이미지가 있으면 이미지 위에 글자를, 없으면 네이비 기본 디자인.
class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({super.key, required this.banner, this.onTap});

  final BannerModel banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageUrl != null;
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage) ...[
              CachedNetworkImage(
                imageUrl: banner.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.chipBackground),
                errorWidget: (_, _, _) => const BannerInkBackground(),
              ),
              // 이미지 위 글자가 읽히도록 왼쪽 아래를 어둡게
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ] else
              const BannerInkBackground(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 96, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미지 없는 배너의 기본 배경 — 네이비 그라데이션 + 잉크 방울.
class BannerInkBackground extends StatelessWidget {
  const BannerInkBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF2E4A73)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 18,
            top: 14,
            child: InkDropCircle(color: Color(0xFF3B6FB6), size: 44),
          ),
          Positioned(
            right: 54,
            bottom: 16,
            child: InkDropCircle(color: Color(0xFF8E2C48), size: 30),
          ),
          Positioned(
            right: 14,
            bottom: 22,
            child: InkDropCircle(color: Color(0xFF2A8C82), size: 24),
          ),
        ],
      ),
    );
  }
}
