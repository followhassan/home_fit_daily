import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Semantic colours that Material's [ColorScheme] does not cover.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentInk,
    required this.success,
    required this.warning,
    required this.error,
    required this.heroGradient,
  });

  /// Cards and sheets.
  final Color surface;

  /// Inputs, chips, tracks.
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Pink for text and icons, readable on this theme's surfaces.
  final Color accentInk;
  final Color success;
  final Color warning;
  final Color error;
  final Gradient heroGradient;

  static const dark = AppPalette(
    surface: AppColors.darkGrey,
    surfaceAlt: AppColors.lightGrey,
    border: AppColors.lightGrey,
    textPrimary: AppColors.white,
    textSecondary: AppColors.textSecondary,
    accentInk: AppColors.premiumPink,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.errorDark,
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A1027), AppColors.darkGrey],
    ),
  );

  static const light = AppPalette(
    surface: AppColors.white,
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    textPrimary: AppColors.deepBlack,
    textSecondary: AppColors.lightTextSecondary,
    accentInk: AppColors.pinkInk,
    success: AppColors.successInk,
    warning: AppColors.warningInk,
    error: AppColors.errorInk,
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFE3F0), AppColors.white],
    ),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => (other == null || t < 0.5) ? this : other;
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
  TextTheme get text => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}

/// Spacing and shape tokens.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const double radiusSm = 12;
  static const double radius = 16;
  static const double radiusLg = 20;

  /// Comfortable minimum tap target.
  static const double tapTarget = 48;

  /// Maximum readable content width on tablets.
  static const double maxContentWidth = 720;
}

/// Material 3 themes for HomeFit using the bundled Inter font.
abstract final class AppTheme {
  static const _font = 'Inter';

  static ThemeData darkTheme() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    background: AppColors.deepBlack,
  );

  static ThemeData lightTheme() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    background: AppColors.lightBackground,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required Color background,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.premiumPink,
      // Dark text on brand pink keeps button labels readable (6.4:1).
      onPrimary: AppColors.deepBlack,
      secondary: palette.accentInk,
      onSecondary: isDark ? AppColors.deepBlack : AppColors.white,
      error: palette.error,
      onError: isDark ? AppColors.deepBlack : AppColors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      surfaceContainerHighest: palette.surfaceAlt,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _font,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [palette],
    );
    final text = _textTheme(base.textTheme, palette);

    return base.copyWith(
      textTheme: text,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Space.radiusLg),
          side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.radius),
          borderSide: const BorderSide(color: AppColors.premiumPink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.radius),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Space.radius),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textSecondary),
        labelStyle: TextStyle(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.premiumPink,
          foregroundColor: AppColors.deepBlack,
          disabledBackgroundColor: palette.surfaceAlt,
          disabledForegroundColor: palette.textSecondary,
          elevation: 0,
          minimumSize: const Size(Space.tapTarget, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radius)),
          textStyle: const TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.premiumPink,
          foregroundColor: AppColors.deepBlack,
          minimumSize: const Size(Space.tapTarget, Space.tapTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radius)),
          textStyle: const TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentInk,
          minimumSize: const Size(Space.tapTarget, Space.tapTarget),
          side: BorderSide(color: palette.accentInk, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radius)),
          textStyle: const TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentInk,
          minimumSize: const Size(Space.tapTarget, Space.tapTarget),
          textStyle: const TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(Space.tapTarget, Space.tapTarget)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        selectedColor: AppColors.premiumPink.withValues(alpha: isDark ? 0.22 : 0.16),
        checkmarkColor: palette.accentInk,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radiusSm)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.deepBlack : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.premiumPink : palette.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.all(palette.border),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.premiumPink,
        linearTrackColor: palette.surfaceAlt,
        circularTrackColor: palette.surfaceAlt,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.premiumPink,
        inactiveTrackColor: palette.surfaceAlt,
        thumbColor: AppColors.premiumPink,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.accentInk,
        unselectedLabelColor: palette.textSecondary,
        indicatorColor: AppColors.premiumPink,
        dividerColor: palette.border,
        labelStyle: const TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabAlignment: TabAlignment.start,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radiusLg)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.lightGrey : AppColors.deepBlack,
        contentTextStyle: const TextStyle(fontFamily: _font, color: AppColors.white, fontSize: 14),
        actionTextColor: AppColors.premiumPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radiusSm)),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? AppColors.premiumPink : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? AppColors.deepBlack : palette.textPrimary,
          ),
          side: WidgetStateProperty.all(BorderSide(color: palette.border)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppPalette palette) {
    TextStyle style(double size, FontWeight weight, {double? spacing, Color? color}) => TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color ?? palette.textPrimary,
    );
    return base.copyWith(
      displayLarge: style(56, FontWeight.w700, spacing: -1),
      displayMedium: style(40, FontWeight.w700, spacing: -0.5),
      displaySmall: style(32, FontWeight.w700, spacing: -0.5),
      headlineLarge: style(28, FontWeight.w700, spacing: -0.3),
      headlineMedium: style(24, FontWeight.w700),
      headlineSmall: style(20, FontWeight.w700),
      titleLarge: style(18, FontWeight.w600),
      titleMedium: style(16, FontWeight.w600),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400),
      bodyMedium: style(14, FontWeight.w400),
      bodySmall: style(12.5, FontWeight.w400, color: palette.textSecondary),
      labelLarge: style(14, FontWeight.w600, spacing: 0.2),
      labelMedium: style(12.5, FontWeight.w600, spacing: 0.2),
      labelSmall: style(11.5, FontWeight.w600, spacing: 0.3),
    );
  }
}
