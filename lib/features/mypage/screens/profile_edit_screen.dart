import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/confirm_discard_dialog.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../../shared/widgets/user_avatar.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

enum _NicknameStatus { idle, checking, available, duplicate }

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  File? _newImage;
  bool _isLoading = false;
  _NicknameStatus _nicknameStatus = _NicknameStatus.idle;
  Timer? _debounce;
  late String _originalNickname;
  late String _originalBio;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _originalNickname = user?.nickname ?? '';
    _originalBio = user?.bio ?? '';
    _nicknameController = TextEditingController(text: _originalNickname);
    _bioController = TextEditingController(text: _originalBio);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onNicknameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty || trimmed == _originalNickname) {
      setState(() => _nicknameStatus = _NicknameStatus.idle);
      return;
    }

    setState(() => _nicknameStatus = _NicknameStatus.checking);
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _checkNickname(trimmed),
    );
  }

  Future<void> _checkNickname(String nickname) async {
    final uid = ref.read(currentUidProvider);
    final available = await ref
        .read(userRepoProvider)
        .isNicknameAvailable(nickname, excludeUid: uid);
    if (!mounted) return;
    setState(
      () => _nicknameStatus = available
          ? _NicknameStatus.available
          : _NicknameStatus.duplicate,
    );
  }

  bool get _canSave =>
      !_isLoading && _nicknameStatus != _NicknameStatus.duplicate;

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    // 닉네임을 변경했는데 아직 체크 중이면 완료 대기
    final trimmed = _nicknameController.text.trim();
    if (trimmed != _originalNickname &&
        _nicknameStatus == _NicknameStatus.checking) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userRepoProvider);
      String? profileUrl;

      if (_newImage != null) {
        profileUrl = await ref
            .read(storageServiceProvider)
            .uploadProfileImage(_newImage!, uid);
      }

      await repo.updateUser(uid, {
        'nickname': trimmed,
        'bio': _bioController.text.trim(),
        if (profileUrl != null)
          'profileImageUrl': profileUrl, // ignore: use_null_aware_elements
      });

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _newImage = File(xfile.path));
  }

  bool get _hasChanges =>
      _nicknameController.text.trim() != _originalNickname ||
      _bioController.text.trim() != _originalBio ||
      _newImage != null;

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    return confirmDiscardDialog(
      context,
      title: '수정 중인 내용이 있어요',
      content: '지금 나가면 변경사항이 저장되지 않습니다.',
      cancelLabel: '계속 편집',
      confirmLabel: '저장하지 않고 나가기',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('프로필 편집'),
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TapScale(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    UserAvatar(
                      localFile: _newImage,
                      imageUrl: user?.profileImageUrl,
                      radius: 52,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
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
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nicknameController,
                    maxLength: AppConstants.maxNickname,
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      suffixIcon: _nicknameStatus == _NicknameStatus.checking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onChanged: _onNicknameChanged,
                  ),
                  if (_nicknameStatus == _NicknameStatus.available)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '사용 가능한 닉네임이에요',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                  if (_nicknameStatus == _NicknameStatus.duplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '이미 사용 중인 닉네임이에요',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLength: AppConstants.maxBio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '소개',
                  hintText: '나를 소개해주세요',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
