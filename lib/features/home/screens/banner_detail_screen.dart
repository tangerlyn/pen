import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/banner_model.dart';
import '../providers/home_discovery_provider.dart';
import '../widgets/home_banner_carousel.dart';

/// 배너를 눌렀을 때 보이는 상세 화면.
/// 홈에서 넘어오면 배너 객체를 그대로 받고, 링크로 바로 들어오면 id로 불러온다.
final _bannerByIdProvider =
    FutureProvider.autoDispose.family<BannerModel?, String>((ref, id) async {
  if (id == BannerModel.welcome.id) return BannerModel.welcome;
  return ref.read(bannerRepoProvider).getBanner(id);
});

class BannerDetailScreen extends ConsumerWidget {
  const BannerDetailScreen({super.key, required this.bannerId, this.initial});

  final String bannerId;
  final BannerModel? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = initial ?? ref.watch(_bannerByIdProvider(bannerId)).valueOrNull;
    final loading = initial == null && ref.watch(_bannerByIdProvider(bannerId)).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: banner == null
          ? Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : Text(
                      '내용을 찾을 수 없어요.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
            )
          : _BannerBody(banner: banner),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.banner});

  final BannerModel banner;

  Future<void> _openLink(BuildContext context) async {
    final link = banner.linkUrl;
    if (link == null) return;
    if (link.startsWith('/')) {
      context.push(link);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
              ),
              children: [
                LayoutBuilder(
                  builder: (context, c) => SizedBox(
                    height: HomeBannerCarousel.cardHeight(context, c.maxWidth),
                    child: HomeBannerCard(banner: banner),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ..._paragraphs(banner.body),
              ],
            ),
          ),
          if (banner.linkUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openLink(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    banner.linkLabel ?? '자세히 보기',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 본문: 빈 줄로 문단을 나누고, `# `로 시작하는 줄은 소제목.
  List<Widget> _paragraphs(String body) {
    final widgets = <Widget>[];
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Text(line.substring(2), style: AppTextStyles.titleMedium),
        ));
      } else {
        widgets.add(Text(
          line,
          style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
        ));
      }
    }
    return widgets;
  }
}
