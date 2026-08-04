import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

class SignupNicknameScreen extends ConsumerStatefulWidget {
  const SignupNicknameScreen({super.key});

  @override
  ConsumerState<SignupNicknameScreen> createState() =>
      _SignupNicknameScreenState();
}

class _SignupNicknameScreenState extends ConsumerState<SignupNicknameScreen> {
  final _controller = TextEditingController();
  bool _isChecking = false;
  bool? _isAvailable;
  String _lastChecked = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkNickname() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty || nickname == _lastChecked) return;

    setState(() {
      _isChecking = true;
      _isAvailable = null;
    });

    final available = await ref
        .read(authProvider.notifier)
        .checkNickname(nickname);
    setState(() {
      _isChecking = false;
      _isAvailable = available;
      _lastChecked = nickname;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _controller.text.trim();
    final canProceed = _isAvailable == true && nickname.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('닉네임 설정')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '닉네임을 입력해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '커뮤니티에서 사용할 이름이에요. 나중에 변경할 수 있어요.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: AppConstants.maxNickname,
                    onChanged: (_) {
                      setState(() {
                        _isAvailable = null;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: '닉네임 입력 (최대 12자)',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isChecking ? null : _checkNickname,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('중복확인'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isAvailable != null)
              Text(
                _isAvailable! ? '사용 가능한 닉네임이에요.' : '이미 사용 중인 닉네임이에요.',
                style: AppTextStyles.labelMedium.copyWith(
                  color: _isAvailable! ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w400,
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: canProceed
                  ? () {
                      ref
                          .read(authProvider.notifier)
                          .setNickname(_controller.text.trim());
                      context.go('/signup/profile');
                    }
                  : null,
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}
