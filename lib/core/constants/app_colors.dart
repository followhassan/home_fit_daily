import 'package:flutter/material.dart';

/// HomeFit brand palette. The pink and black values are the established
/// brand identity; additional shades exist only to keep text readable on
/// light backgrounds and to give status colours sufficient contrast.
abstract final class AppColors {
  static const Color deepBlack = Color(0xFF0D0D0D);
  static const Color premiumPink = Color(0xFFFF4FA3);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFF2A2A2A);
  static const Color mediumGrey = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);

  /// Darker brand pink for pink *text and icons* on light surfaces
  /// (5.3:1 on white; the brand pink itself is 3:1).
  static const Color pinkInk = Color(0xFFC8246F);

  /// Light-theme neutrals (from the original light theme).
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurfaceAlt = Color(0xFFF0F0F0);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightTextSecondary = Color(0xFF5C5C5C);

  /// Status colours with readable contrast on light surfaces.
  static const Color successInk = Color(0xFF15803D);
  static const Color warningInk = Color(0xFFB45309);
  static const Color errorDark = Color(0xFFFF8A80);
  static const Color errorInk = Color(0xFFC62828);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4FA3), Color(0xFFFF1F8F)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
  );

  static const LinearGradient pinkBlackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4FA3), Color(0xFF0D0D0D)],
    stops: [0.0, 1.0],
  );
}
