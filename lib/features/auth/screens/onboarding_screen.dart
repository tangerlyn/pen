import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPageData(
    icon: Icons.edit_note,
    title: '${AppConstants.appNameKorean}에 오신 걸 환영해요',
    description: '만년필과 잉크를 사랑하는 사람들이 모인\n필기구 커뮤니티예요',
  ),
  _OnboardingPageData(
    icon: Icons.grid_view_rounded,
    title: '리뷰로 취향을 기록해요',
    description: '써본 펜과 잉크의 리뷰를 남기고\n다른 사람들의 리뷰도 살펴보세요',
  ),
  _OnboardingPageData(
    icon: Icons.forum_rounded,
    title: '커뮤니티에서 이야기해요',
    description: '필기구에 대한 궁금증, 정보, 일상을\n자유롭게 나눠보세요',
  ),
  _OnboardingPageData(
    icon: Icons.book_rounded,
    title: '나만의 아카이브를 만들어요',
    description: '보유한 잉크와 펜을 기록하고\n나만의 잉크 차트를 완성해보세요',
  ),
  _OnboardingPageData(
    icon: Icons.favorite_rounded,
    title: '이제 시작해볼까요?',
    description: '${AppConstants.appNameKorean}과 함께 필기구 생활을\n더 즐겁게 만들어보세요',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.go('/');

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Opacity(
                  opacity: isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    child: const Text(
                      '건너뛰기',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: _pages.length,
              effect: const WormEffect(
                dotHeight: 7,
                dotWidth: 7,
                activeDotColor: AppColors.primary,
                dotColor: AppColors.divider,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                  child: Text(isLast ? '시작하기' : '다음'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
