import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class VocesColors {
  static const ink = Color(0xFF1B2420);
  static const field = Color(0xFFD7E0D4);
  static const paper = Color(0xFFF3F6F1);
  static const seal = Color(0xFF9E3A32);
  static const moss = Color(0xFF2F5D45);
  static const line = Color(0xFFC5D0C0);
  static const muted = Color(0xFF5C675F);
}

ThemeData vocesTheme() {
  final text = GoogleFonts.sourceSans3TextTheme().apply(
    bodyColor: VocesColors.ink,
    displayColor: VocesColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: VocesColors.field,
    colorScheme: ColorScheme.fromSeed(
      seedColor: VocesColors.moss,
      primary: VocesColors.moss,
      surface: VocesColors.paper,
    ),
    textTheme: text.copyWith(
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 40,
        fontWeight: FontWeight.w500,
        color: VocesColors.ink,
        height: 1.05,
      ),
      titleLarge: GoogleFonts.newsreader(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: VocesColors.ink,
        height: 1.15,
      ),
      bodyLarge: GoogleFonts.sourceSans3(fontSize: 18, height: 1.45, color: VocesColors.ink),
      bodyMedium: GoogleFonts.sourceSans3(fontSize: 16, height: 1.45, color: VocesColors.ink),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VocesColors.field,
      foregroundColor: VocesColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: VocesColors.paper,
      indicatorColor: VocesColors.field,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: VocesColors.paper,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)), borderSide: BorderSide(color: VocesColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)), borderSide: BorderSide(color: VocesColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)), borderSide: BorderSide(color: VocesColors.moss, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)), borderSide: BorderSide(color: VocesColors.seal)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VocesColors.seal,
        foregroundColor: VocesColors.paper,
        minimumSize: const Size(44, 44),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VocesColors.ink,
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: VocesColors.moss),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: VocesColors.moss, minimumSize: const Size(44, 44)),
    ),
  );
}
