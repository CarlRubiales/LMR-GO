import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final accentButton = FilledButton.styleFrom(
    backgroundColor: AppColors.orange,
    foregroundColor: AppColors.cream,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)
          ? AppColors.terracottaDark
          : null,
    ),
  );

  static final dangerButton = FilledButton.styleFrom(
    backgroundColor: AppColors.failed,
    foregroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
  );

  static ThemeData get light {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.plum,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.blush1,
      onPrimaryContainer: AppColors.plum,
      secondary: AppColors.orange,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.blush2,
      onSecondaryContainer: AppColors.plum,
      tertiary: AppColors.delivered,
      onTertiary: AppColors.white,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.cream,
      surfaceContainerLow: AppColors.blush1,
      surfaceContainer: AppColors.cream,
      surfaceContainerHigh: AppColors.blush2,
      surfaceContainerHighest: AppColors.line,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.line,
      outlineVariant: AppColors.formBorder,
      error: AppColors.failed,
      onError: AppColors.white,
      errorContainer: AppColors.failedSoft,
      onErrorContainer: AppColors.failed,
    );

    final baseInter = GoogleFonts.interTextTheme();
    final textTheme = baseInter.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        textStyle: baseInter.displayLarge,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        textStyle: baseInter.displayMedium,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        textStyle: baseInter.displaySmall,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        textStyle: baseInter.headlineLarge,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        textStyle: baseInter.headlineMedium,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        textStyle: baseInter.headlineSmall,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        textStyle: baseInter.titleLarge,
        color: AppColors.plum,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: baseInter.titleMedium,
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.inter(
        textStyle: baseInter.titleSmall,
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseInter.bodyLarge,
        color: AppColors.ink,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseInter.bodyMedium,
        color: AppColors.ink,
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: baseInter.bodySmall,
        color: AppColors.muted,
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: baseInter.labelLarge,
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: baseInter.labelMedium,
        color: AppColors.ink,
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: baseInter.labelSmall,
        color: AppColors.muted,
      ),
    );

    final inputBorderShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.plum),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.plum,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.plum.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.plum,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)
                ? AppColors.plumLight
                : null,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.plum,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)
                ? AppColors.plumLight
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.plum,
          side: const BorderSide(color: AppColors.inputBorder, width: 1),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.plum,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        labelStyle: GoogleFonts.inter(
          color: AppColors.plum,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.inputHint,
          fontSize: 13,
        ),
        prefixIconColor: AppColors.inputIcon,
        suffixIconColor: AppColors.inputIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorderShape,
        enabledBorder: inputBorderShape,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.failed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.failed, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.blush1,
        selectedColor: AppColors.plum,
        disabledColor: AppColors.line,
        side: const BorderSide(color: AppColors.line, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: GoogleFonts.inter(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: AppColors.cream,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cream,
        indicatorColor: AppColors.blush2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.plum
                : AppColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.plum
                : AppColors.muted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.plum,
        unselectedItemColor: AppColors.muted,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.plum,
        foregroundColor: AppColors.cream,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.ink,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.orange,
        linearTrackColor: AppColors.blush2,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.orange,
        textColor: AppColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.plum,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.inter(color: AppColors.cream),
      ),
    );
  }
}

