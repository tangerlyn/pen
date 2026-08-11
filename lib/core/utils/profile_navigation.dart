import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/providers.dart';

Future<void> navigateToProfile(
  BuildContext context,
  WidgetRef ref,
  String uid,
) async {
  final user = await ref.read(userRepoProvider).getUser(uid);
  if (!context.mounted) return;
  if (user == null) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('탈퇴한 사용자입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  } else {
    context.push('/profile/$uid');
  }
}
