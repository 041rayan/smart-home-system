import 'package:flutter/material.dart';

class AppColors {
  // Deep AMOLED Blacks
  static const Color background = Color(0xFF090A0E);
  static const Color cardSurface = Color(0xFF13141B);
  static const Color cardElevated = Color(0xFF1A1B24);
  static const Color cardBorder = Color(0xFF232532);
  static const Color cardBorderActive = Color(0xFFFF2D78);

  // Vibrant Pink Palette
  static const Color primaryPink = Color(0xFFFF2D78);
  static const Color hotPink = Color(0xFFFF1B6B);
  static const Color softPink = Color(0xFFFF6BA0);
  static const Color pinkTint = Color(0xFF27131D);
  static const Color pinkGlow = Color(0x40FF2D78);

  // Gradients
  static const LinearGradient primaryPinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF2D78), Color(0xFFFF5E98)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF15161F), Color(0xFF101118)],
  );

  static const LinearGradient waterGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF2D78), Color(0xFF8B2FC9)],
  );

  // Functional Status Colors
  static const Color online = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color fireAlert = Color(0xFFFF2D55);
  static const Color coolBlue = Color(0xFF00C0FF);

  // Typography Colors
  static const Color textWhite = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA1B4);
  static const Color textMuted = Color(0xFF5D6175);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryPink,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPink,
        secondary: AppColors.softPink,
        surface: AppColors.cardSurface,
        error: AppColors.fireAlert,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPink;
          }
          return AppColors.cardElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPink;
          }
          return AppColors.cardBorder;
        }),
      ),
    );
  }
}
