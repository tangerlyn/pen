import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../providers/auth_provider.dart';

class SignupProfileScreen extends ConsumerStatefulWidget {
  const SignupProfileScreen({super.key});

  @override
  ConsumerState<SignupProfileScreen> createState() =>
      _SignupProfileScreenState();
}

class _SignupProfileScreenState extends ConsumerState<SignupProfileScreen> {
  File? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() => _imageFile = File(xfile.path));
      ref.read(authProvider.notifier).setProfileImagePath(xfile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 사진')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '프로필 사진을 설정해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '나중에 언제든지 변경할 수 있어요. (선택)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  UserAvatar(localFile: _imageFile, radius: 64),
                  Positioned(
                    bottom: 4,
                    right: 4,
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
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/signup/interests'),
              child: const Text('다음'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/signup/interests'),
              child: const Text(
                '건너뛰기',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
