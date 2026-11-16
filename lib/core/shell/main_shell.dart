import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/level_system.dart';
import '../../data/services/force_update_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/level_up_dialog.dart';
import '../../shared/widgets/tap_scale.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
      _checkForceUpdate();
    });
  }

  Future<void> _checkForceUpdate() async {
    final requirement = await ForceUpdateService.checkUpdate();
    if (!mounted) return;
    switch (requirement) {
      case UpdateRequirement.required:
        ForceUpdateService.showForceUpdateDialog(context);
      case UpdateRequirement.optional:
        ForceUpdateService.showOptionalUpdateDialog(context);
      case UpdateRequirement.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 레벨업 다이얼로그
    ref.listen<LevelUpInfo?>(levelUpProvider, (_, LevelUpInfo? levelUp) {
      if (levelUp == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => LevelUpDialog(info: levelUp),
        ).whenComplete(() {
          ref.read(levelUpProvider.notifier).state = null;
        });
      });
    });

    // 알림 탭 → 화면 이동
    ref.listen<String?>(pendingRouteProvider, (_, route) {
      if (route == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.push(route);
        ref.read(pendingRouteProvider.notifier).state = null;
      });
    });

    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Scaffold(
      // 떠 있는 하단 바 뒤로 화면이 비쳐 보이도록 본문을 바 아래까지 늘린다.
      // 이때 본문의 MediaQuery.padding.bottom이 바 높이만큼 커지므로, 각 탭 화면은
      // 목록 끝·플로팅 버튼을 그만큼 띄운다 (MediaQuery.paddingOf(context).bottom).
      extendBody: true,
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isOnline
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '인터넷 연결이 없어요',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(child: widget.shell),
        ],
      ),
      bottomNavigationBar: _BottomNav(shell: widget.shell),
    );
  }
}

/// 떠 있는 캡슐 모양 하단 바 — 반투명 유리 효과, 선택한 탭은 회색 알약 배경.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '홈'),
    (icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: '리뷰'),
    (icon: Icons.forum_outlined, activeIcon: Icons.forum_rounded, label: '커뮤니티'),
    (icon: Icons.book_outlined, activeIcon: Icons.book_rounded, label: '아카이브'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // 홈 인디케이터가 있는 폰은 그 위에 살짝 겹치게, 없는 폰은 12만큼 띄운다.
    final bottomGap = safeBottom > 0 ? safeBottom - 6 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1,
                ),
              ),
              // 기본 높이를 유지하되, 큰 글자에서는 아이콘+라벨 높이만큼 늘어난다.
              // 선택 표시(회색 알약)는 탭 뒤에 한 장만 두고, 탭을 바꾸면 그 자리로
              // 미끄러지듯 옮겨 간다.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / _items.length;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 54),
                    child: IntrinsicHeight(
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 380),
                            curve: const Cubic(0.2, 0.9, 0.3, 1.04),
                            left: slot * shell.currentIndex,
                            top: 0,
                            bottom: 0,
                            width: slot,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBECEF),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _items.length; i++)
                                _NavItem(
                                  icon: _items[i].icon,
                                  activeIcon: _items[i].activeIcon,
                                  label: _items[i].label,
                                  index: i,
                                  shell: shell,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.shell,
  });

  static const _rootPaths = [
    '/',
    '/review',
    '/community',
    '/archive',
    '/mypage',
  ];

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = shell.currentIndex == index;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: TapScale(
        onTap: () {
          if (index == shell.currentIndex) {
            // 같은 탭 재탭: context.go()로 스택 강제 리셋
            // goBranch(initialLocation: true)는 현재 브랜치에서 no-op 처리되는 버그가 있음
            context.go(_rootPaths[index]);
            // 스크롤이 이미 맨 위여도(=탭 스택 리셋만 필요한 경우) 계속 같은 값을
            // 넣으면 ref.listen이 이전값과 같아 감지를 못하므로, 화면 쪽에서
            // 소비 후 null로 되돌리는 패턴과 짝을 맞춰 매번 새 신호로 취급한다.
            ref.read(scrollToTopTabProvider.notifier).state = index;
          } else {
            shell.goBranch(index);
          }
        },
        // 투명색이라도 지정해야 칸 전체가 눌린다 (TapScale은 deferToChild).
        child: ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              tween: ColorTween(end: color),
              builder: (context, c, _) => Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.85, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: c,
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: c,
                      fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
