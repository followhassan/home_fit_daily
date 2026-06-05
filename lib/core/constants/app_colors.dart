import 'package:flutter/material.dart';

/// Premium color palette for HomeFit.
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

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
  );

  static const LinearGradient pinkBlackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4FA3), Color(0xFF0D0D0D)],
    stops: [0.0, 1.0],
  );
}
