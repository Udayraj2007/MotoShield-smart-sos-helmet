import 'package:flutter/material.dart';

class AppColors {
  final bool isDark;

  AppColors.of(BuildContext context)
      : isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

  // Backgrounds
  // Page background: Dark Tactical Navy #070B14, Light Soft Icy Blue-Grey #F4F7FB
  Color get scaffoldBackground => isDark ? const Color(0xFF070B14) : const Color(0xFFF4F7FB);

  // Cards / Elevated Blocks: Dark Navy #0E1424, Light Pure White #FFFFFF
  Color get cardBackground => isDark ? const Color(0xFF0E1424) : const Color(0xFFFFFFFF);

  // Inner container / icons / badges: Dark #0B0F1B, Light Soft Blue #F0F4F9
  Color get innerBoxBackground => isDark ? const Color(0xFF0B0F1B) : const Color(0xFFF0F4F9);
  Color get innerContainerBackground => innerBoxBackground;

  // Card Borders: Dark Cyan-Navy #1B2438, Light Soft Blue Border #E2E8F0
  Color get cardBorder => isDark ? const Color(0xFF1B2438) : const Color(0xFFE2E8F0);

  // Text
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF8A99B5) : const Color(0xFF64748B);

  // Accents & Dynamic Blue
  Color get primaryAccent => isDark ? const Color(0xFF00E5FF) : const Color(0xFF0088CC);
  Color get primaryAccentBg => isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : const Color(0xFFE5F6FF);

  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color orangeAccent = Color(0xFFFF5E3A);
  static const Color greenAccent = Color(0xFF00E676);
  static const Color redAccent = Color(0xFFE52E2E);
  static const Color peachAccent = Color(0xFFFF7A59);

  // Pill Navigation Bar
  Color get pillNavBackground => isDark ? const Color(0xFF0E1424) : const Color(0xFFFFFFFF);
  Color get pillNavActiveCircle => isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : const Color(0xFFE5F6FF);
  Color get pillNavActiveIcon => isDark ? const Color(0xFF00E5FF) : const Color(0xFF0088CC);
  Color get pillNavInactiveIcon => isDark ? const Color(0xFF5A6E8C) : const Color(0xFF94A3B8);

  // Dialogs & Modals
  Color get modalBackground => isDark ? const Color(0xFF0E1424) : const Color(0xFFFFFFFF);
}

