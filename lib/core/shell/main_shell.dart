import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/level_system.dart';
import '../../data/services/force_update_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/level_up_dialog.dart';

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
    final needs = await ForceUpdateService.needsUpdate();
    if (needs && mounted) {
      ForceUpdateService.showForceUpdateDialog(context);
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '인터넷 연결이 없어요',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈', index: 0, shell: shell),
              _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: '리뷰', index: 1, shell: shell),
              _NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: '커뮤니티', index: 2, shell: shell),
              _NavItem(icon: Icons.book_outlined, activeIcon: Icons.book, label: '아카이브', index: 3, shell: shell),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: '마이', index: 4, shell: shell),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.shell,
  });

  static const _rootPaths = ['/', '/review', '/community', '/archive', '/mypage'];

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isActive = shell.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == shell.currentIndex) {
            // 같은 탭 재탭: context.go()로 스택 강제 리셋
            // goBranch(initialLocation: true)는 현재 브랜치에서 no-op 처리되는 버그가 있음
            context.go(_rootPaths[index]);
          } else {
            shell.goBranch(index);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
              child: Text(label),
            ),
            SizedBox(
              height: 5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(top: 2),
                width: isActive ? 4.0 : 0.0,
                height: isActive ? 4.0 : 0.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.primary : Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
