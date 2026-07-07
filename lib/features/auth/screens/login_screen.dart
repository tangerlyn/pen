import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);

    ref.listen(authProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 로고
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '문어다방',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '만년필·잉크·노트 커뮤니티',
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              // 소셜 로그인 버튼들
              if (state.isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    _KakaoLoginButton(
                      onTap: () => ref.read(authProvider.notifier).signInWithKakao(context),
                    ),
                    const SizedBox(height: 12),
                    _NaverLoginButton(
                      onTap: () => ref.read(authProvider.notifier).signInWithNaver(context),
                    ),
                    const SizedBox(height: 12),
                    _AppleLoginButton(
                      onTap: () => ref.read(authProvider.notifier).signInWithApple(context),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Text(
                '로그인하면 서비스 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주됩니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _KakaoLoginButton extends StatelessWidget {
  const _KakaoLoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF3A1D1D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble, size: 20),
            SizedBox(width: 8),
            Text('카카오로 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _NaverLoginButton extends StatelessWidget {
  const _NaverLoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF03C75A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('N', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(width: 8),
            Text('네이버로 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AppleLoginButton extends StatelessWidget {
  const _AppleLoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, size: 22),
            SizedBox(width: 8),
            Text('Apple로 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
