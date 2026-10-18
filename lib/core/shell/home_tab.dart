import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/record/screens/record_home_screen.dart';
import '../config/home_variant.dart';

/// 첫 탭 화면. 기본은 기록 홈, Remote Config로 롤백하면 기존 디스커버리 홈.
/// 값을 읽는 동안에는 기본값(기록 홈)을 보여준다.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(homeVariantProvider).valueOrNull ?? HomeVariant.record;
    return switch (variant) {
      HomeVariant.record => const RecordHomeScreen(),
      HomeVariant.discover => const HomeScreen(),
    };
  }
}
