import 'package:flutter/material.dart';

abstract final class CmsTheme {
  static const canvasColor = Color(0xFF0B0F19);
  static const surfaceColor = Color(0xFF161F30);
  static const cardColor = Color(0xFF1E293B);
  static const borderColor = Color(0xFF334155);
  static const primaryAccent = Color(0xFF38BDF8);
  static const secondaryAccent = Color(0xFF818CF8);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const successColor = Color(0xFF10B981);
  static const successBg = Color(0xFF064E3B);
  static const successText = Color(0xFF6EE7B7);

  static const warningColor = Color(0xFFF59E0B);
  static const warningBg = Color(0xFF78350F);
  static const warningText = Color(0xFFFDE68A);

  static const dangerColor = Color(0xFFEF4444);
  static const dangerBg = Color(0xFF7F1D1D);
  static const dangerText = Color(0xFFFCA5A5);

  static const infoColor = Color(0xFF0EA5E9);
  static const infoBg = Color(0xFF0C4A6E);
  static const infoText = Color(0xFFBAE6FD);

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      surface: surfaceColor,
      primary: primaryAccent,
      secondary: secondaryAccent,
      error: dangerColor,
      onSurface: textPrimary,
      onPrimary: Color(0xFF0B0F19),
      onSecondary: Color(0xFF0B0F19),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvasColor,
      colorScheme: colorScheme,
      cardColor: cardColor,
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: const Color(0xFF0B0F19),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 24,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
