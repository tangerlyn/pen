import 'package:flutter/material.dart';

// ── Colors ────────────────────────────────────────────────────────────────

abstract class AppColors {
  static const primary = Color(0xFF2C2C2C);
  static const secondary = Color(0xFF5C6BC0);
  static const accent = Color(0xFF7E57C2);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFB8C00);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textTertiary = Color(0xFFBDBDBD);

  static const divider = Color(0xFFEEEEEE);
  static const chipBackground = Color(0xFFF5F5F5);
  static const chipSelected = Color(0xFF2C2C2C);

  static const mannerHot = Color(0xFFFF5722);
  static const mannerWarm = Color(0xFFFF9800);
  static const mannerNormal = Color(0xFF4CAF50);
  static const mannerCool = Color(0xFF2196F3);

  // Shadow helpers
  static const cardShadowColor = Color(0x0F000000); // black 6%
}

// ── Text Styles ───────────────────────────────────────────────────────────

abstract class AppTextStyles {
  // Headlines — 화면·섹션 타이틀 등 큰 제목
  static const headlineLarge = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const headlineMedium = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const headlineSmall = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Titles — 카드·앱바·모달 제목
  static const titleLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Body — 본문
  static const bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  // Labels — 보조 텍스트
  static const labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const labelMedium = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary);
  static const caption = TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textTertiary);

  // Semantic aliases
  static const sectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3);
  static const appBarTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
}

// ── Spacing ───────────────────────────────────────────────────────────────

abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double section = 24.0;

  // Reusable EdgeInsets
  static const pagePadding = EdgeInsets.symmetric(horizontal: lg);
  static const cardPadding = EdgeInsets.all(md);
  static const listItemPadding = EdgeInsets.symmetric(horizontal: xl, vertical: sm);
  static const sectionHeaderPadding = EdgeInsets.fromLTRB(xl, section, lg, md);
}

// ── Button Styles ─────────────────────────────────────────────────────────

abstract class AppButtonStyles {
  static ButtonStyle get primary => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTextStyles.titleMedium,
      );

  static ButtonStyle get outlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTextStyles.titleMedium,
      );

  static ButtonStyle get ghost => TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

// ── Theme ─────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Pretendard',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.chipBackground,
          selectedColor: AppColors.chipSelected,
          labelStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm - 2),
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.headlineLarge,
          headlineMedium: AppTextStyles.headlineMedium,
          headlineSmall: AppTextStyles.headlineSmall,
          titleLarge: AppTextStyles.titleLarge,
          titleMedium: AppTextStyles.titleMedium,
          titleSmall: AppTextStyles.titleSmall,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.labelLarge,
          labelMedium: AppTextStyles.labelMedium,
          labelSmall: AppTextStyles.labelSmall,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.chipBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppButtonStyles.primary,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppButtonStyles.outlined,
        ),
        dividerTheme: const DividerThemeData(
            color: AppColors.divider, thickness: 1, space: 1),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
      );
}
