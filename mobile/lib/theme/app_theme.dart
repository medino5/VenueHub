import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.rausch,
    required this.ink,
    required this.secondaryText,
    required this.divider,
    required this.surfaceGray,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color rausch;
  final Color ink;
  final Color secondaryText;
  final Color divider;
  final Color surfaceGray;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  AppColors copyWith({
    Color? rausch,
    Color? ink,
    Color? secondaryText,
    Color? divider,
    Color? surfaceGray,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      rausch: rausch ?? this.rausch,
      ink: ink ?? this.ink,
      secondaryText: secondaryText ?? this.secondaryText,
      divider: divider ?? this.divider,
      surfaceGray: surfaceGray ?? this.surfaceGray,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      rausch: Color.lerp(rausch, other.rausch, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surfaceGray: Color.lerp(surfaceGray, other.surfaceGray, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class AppTheme {
  static const rausch = Color(0xFFFF385C);
  static const ink = Color(0xFF222222);
  static const secondaryText = Color(0xFF717171);
  static const divider = Color(0xFFEBEBEB);
  static const surfaceGray = Color(0xFFF7F7F7);
  static const success = Color(0xFF008A05);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFC13515);

  // Compatibility aliases for the existing screens while the UI is migrated.
  static const navy = ink;
  static const blue = rausch;
  static const sky = surfaceGray;
  static const line = divider;
  static const coral = rausch;
  static const sand = Colors.white;
  static const teal = rausch;

  static const radiusCard = 12.0;
  static const radiusInput = 8.0;
  static const radiusPill = 50.0;

  static AppColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      const AppColors(
        rausch: rausch,
        ink: ink,
        secondaryText: secondaryText,
        divider: divider,
        surfaceGray: surfaceGray,
        success: success,
        warning: warning,
        danger: danger,
      );

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final appColors = AppColors(
      rausch: rausch,
      ink: isDark ? Colors.white : ink,
      secondaryText: isDark ? const Color(0xFFB0B0B0) : secondaryText,
      divider: isDark ? const Color(0xFF333333) : divider,
      surfaceGray: isDark ? const Color(0xFF161616) : surfaceGray,
      success: success,
      warning: warning,
      danger: danger,
    );
    final baseScheme = ColorScheme.fromSeed(
      seedColor: rausch,
      brightness: brightness,
    );
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      isDark ? Typography.whiteMountainView : Typography.blackMountainView,
    ).apply(bodyColor: appColors.ink, displayColor: appColors.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme.copyWith(
        primary: rausch,
        secondary: ink,
        surface: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        onSurface: appColors.ink,
        outline: appColors.divider,
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      extensions: [appColors],
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.35,
          color: appColors.secondaryText,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        foregroundColor: appColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: appColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(color: appColors.divider, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        selectedItemColor: rausch,
        unselectedItemColor: appColors.secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: appColors.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF161616) : surfaceGray,
        prefixIconColor: appColors.ink,
        hintStyle: TextStyle(color: appColors.secondaryText),
        labelStyle: TextStyle(color: appColors.secondaryText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: appColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: appColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: rausch, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rausch,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rausch,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appColors.ink,
          minimumSize: const Size(44, 44),
          side: BorderSide(color: appColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: appColors.surfaceGray,
        selectedColor: ink,
        labelStyle: TextStyle(color: appColors.ink),
        side: BorderSide(color: appColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      splashColor: surfaceGray,
      highlightColor: surfaceGray,
    );
  }
}
