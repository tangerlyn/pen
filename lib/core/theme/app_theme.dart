import 'package:flutter/material.dart';

// ── Colors ────────────────────────────────────────────────────────────────

abstract class AppColors {
  static const primary = Color(0xFF1B2E4B);
  static const secondary = Color(0xFF2E4A6E);
  static const accent = Color(0xFF3D6A9E);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFB8C00);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textTertiary = Color(0xFFBDBDBD);

  static const divider = Color(0xFFEEEEEE);
  static const chipBackground = Color(0xFFF2F4F7);
  static const chipSelected = Color(0xFF1B2E4B);

  static const mannerHot = Color(0xFFFF5722);
  static const mannerWarm = Color(0xFFFF9800);
  static const mannerNormal = Color(0xFF4CAF50);
  static const mannerCool = Color(0xFF2196F3);

  // Shadow helpers
  static const cardShadowColor = Color(0x0F000000); // black 6%
}

// ── Glass ────────────────────────────────────────────────────────────────

abstract class AppGlass {
  static const Color cardColor = Color(0xCCFFFFFF);       // 80% 흰색
  static const Color cardBorderColor = Color(0x99FFFFFF); // 60% 흰 테두리
  static const double blur = 10.0;
  static const double cardOpacity = 0.80;

  // 앱 전체 배경 — 흰색에 아주 살짝 파란기
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF4F7FF), // 흰색 + 미세한 블루
      Color(0xFFF8FAFF), // 거의 흰색
    ],
  );
}

// ── Shadows ───────────────────────────────────────────────────────────────

abstract class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> nav = [
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
}

// ── Border Radius ────────────────────────────────────────────────────────
abstract class AppRadius {
  static const double xs = 4.0;   // 뱃지, 태그
  static const double sm = 8.0;   // 칩, 입력 필드
  static const double md = 12.0;  // 카드, 바텀시트, 이미지
  static const double lg = 16.0;  // 모달, 대형 카드
  static const double xl = 20.0;  // 필 버튼
  static const double full = 100.0; // 완전 원형

  static BorderRadius get cardAll => BorderRadius.circular(md);
  static BorderRadius get imageAll => BorderRadius.circular(md);
  static BorderRadius get buttonAll => BorderRadius.circular(sm);
  static BorderRadius get chipAll => BorderRadius.circular(xl);
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
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
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
