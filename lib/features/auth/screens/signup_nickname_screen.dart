import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../mypage/screens/ink_crop_screen.dart';
import '../../mypage/screens/terms_screen.dart';
import '../../mypage/screens/privacy_screen.dart';
import '../../mypage/widgets/ink_swatch_shape.dart';
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

  File? _imageFile;

  bool _ageConfirmed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;

  bool get _allAgreed => _ageConfirmed && _termsAgreed && _privacyAgreed;

  void _setAllAgreed(bool value) {
    setState(() {
      _ageConfirmed = value;
      _termsAgreed = value;
      _privacyAgreed = value;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => InkCropScreen(
          imageFile: File(xfile.path),
          shape: InkSwatchShape.circle,
        ),
      ),
    );
    if (cropped == null) return;
    setState(() => _imageFile = cropped);
    ref.read(authProvider.notifier).setProfileImagePath(cropped.path);
  }

  // 라우터 redirect는 프로필 완성 전엔 /signup/* 밖의 경로를 전부 튕겨내므로,
  // go_router 대신 Navigator로 직접 화면을 띄운다.
  void _openFullText(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

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

    try {
      final available = await ref
          .read(authProvider.notifier)
          .checkNickname(nickname);
      if (!mounted) return;
      setState(() {
        _isAvailable = available;
        _lastChecked = nickname;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 확인하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // 가입을 이어가지 않고 다른 소셜 계정으로 들어가고 싶을 때의 출구.
  // 로그아웃하면 라우터 redirect가 /login으로 보낸다.
  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _controller.text.trim();
    final state = ref.watch(authProvider);
    final canProceed =
        _isAvailable == true &&
        nickname.isNotEmpty &&
        _allAgreed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
        actions: [
          TextButton(
            onPressed: state.isLoading ? null : _signOut,
            child: const Text(
              '다른 계정으로 로그인',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '닉네임과 프로필 사진을\n설정해주세요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '나중에 언제든지 변경할 수 있어요. 프로필 사진은 선택이에요.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      UserAvatar(localFile: _imageFile, radius: 48),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: AppConstants.maxNickname,
                      onChanged: (_) {
                        setState(() {
                          _isAvailable = null;
                          _lastChecked = '';
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
              const SizedBox(height: 36),
              _AllAgreeTile(value: _allAgreed, onChanged: _setAllAgreed),
              const Divider(height: 28),
              // 개인정보 보호법 제22조의2: 만 14세 미만은 법정대리인 동의가 필요한데
              // 그 절차가 없으므로 가입 자체를 만 14세 이상으로 제한한다.
              _AgreeTile(
                label: '[필수] 만 14세 이상입니다',
                value: _ageConfirmed,
                onChanged: (v) => setState(() => _ageConfirmed = v),
              ),
              _AgreeTile(
                label: '[필수] 이용약관 동의',
                value: _termsAgreed,
                onChanged: (v) => setState(() => _termsAgreed = v),
                onViewDetail: () => _openFullText(const TermsScreen()),
              ),
              _AgreeTile(
                label: '[필수] 개인정보처리방침 동의',
                value: _privacyAgreed,
                onChanged: (v) => setState(() => _privacyAgreed = v),
                onViewDetail: () => _openFullText(const PrivacyScreen()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: canProceed && !state.isLoading
                    ? () {
                        ref
                            .read(authProvider.notifier)
                            .setNickname(_controller.text.trim());
                        ref.read(authProvider.notifier).completeSignup(context);
                      }
                    : null,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAgreeTile extends StatelessWidget {
  const _AllAgreeTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.check_circle_outline,
              color: value ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            const Text(
              '전체 동의',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreeTile extends StatelessWidget {
  const _AgreeTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onViewDetail,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Row(
                children: [
                  Icon(
                    value ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 20,
                    color: value ? AppColors.primary : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(label, style: AppTextStyles.bodyMedium)),
                ],
              ),
            ),
          ),
          if (onViewDetail != null)
            TextButton(
              onPressed: onViewDetail,
              child: const Text(
                '보기',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
