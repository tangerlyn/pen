import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class NibpenApp extends ConsumerWidget {
  const NibpenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Nibpen',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // 모든 라우트(탭 + 상세 화면 전부)의 루트 배경 = 글래스 그라데이션
      builder: (context, child) => Container(
        decoration: const BoxDecoration(gradient: AppGlass.backgroundGradient),
        child: child!,
      ),
    );
  }
}
