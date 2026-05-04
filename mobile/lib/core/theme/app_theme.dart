import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF182230);
  static const navy = Color(0xFF05264D);
  static const blue = Color(0xFF1689D6);
  static const sky = Color(0xFFEAF6FF);
  static const line = Color(0xFFE6EDF5);
  static const coral = blue;
  static const sand = Colors.white;
  static const teal = blue;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: navy,
      secondary: blue,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: Typography.blackMountainView
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodyMedium: const TextStyle(
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
            bodyLarge: const TextStyle(
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
            titleMedium: const TextStyle(fontWeight: FontWeight.w600),
            titleLarge: const TextStyle(fontWeight: FontWeight.w700),
            headlineSmall: const TextStyle(fontWeight: FontWeight.w800),
          ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: navy,
        unselectedItemColor: Colors.black45,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        prefixIconColor: navy,
        hintStyle: const TextStyle(color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
