import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class VocesColors {
  static const desk = Color(0xFF1F4D3D);
  static const paper = Color(0xFFFBF3DD);
  static const paperLine = Color(0xFFE6D9B0);
  static const ink = Color(0xFF1B231C);
  static const inkOnDesk = Color(0xFFF2ECD8);
  static const muted = Color(0xFF6B7A66);
  static const mutedOnDesk = Color(0xFF9FC2AE);
  static const marigold = Color(0xFFEFA320);
  static const marigoldDeep = Color(0xFFC8830E);
  static const cobalt = Color(0xFF1E6FB8);
  static const crimson = Color(0xFFC23B2E);
  static const pending = Color(0xFF8C7A4E);
  static const rejected = Color(0xFF746B63);
  static const mapGround = Color(0xFF123449);

  static const field = desk;
  static const moss = cobalt;
  static const seal = crimson;
  static const line = paperLine;
}

TextStyle vocesDisplay(double size, {Color color = VocesColors.ink, FontWeight weight = FontWeight.w500}) {
  return GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color, height: 1.05);
}

TextStyle vocesSans({double size = 15, Color color = VocesColors.ink, FontWeight weight = FontWeight.w400, double height = 1.5}) {
  return GoogleFonts.publicSans(fontSize: size, fontWeight: weight, color: color, height: height);
}

TextStyle vocesMono({double size = 12, Color color = VocesColors.muted}) {
  return GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: FontWeight.w500, height: 1.3);
}

ThemeData vocesTheme() {
  final text = GoogleFonts.publicSansTextTheme().apply(
    bodyColor: VocesColors.ink,
    displayColor: VocesColors.ink,
  );
  final shape = const RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: VocesColors.desk,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: VocesColors.marigold,
      onPrimary: VocesColors.ink,
      secondary: VocesColors.cobalt,
      onSecondary: VocesColors.inkOnDesk,
      error: VocesColors.crimson,
      onError: VocesColors.paper,
      surface: VocesColors.paper,
      onSurface: VocesColors.ink,
    ),
    textTheme: text.copyWith(
      headlineMedium: vocesDisplay(36, color: VocesColors.inkOnDesk),
      titleLarge: vocesDisplay(22),
      bodyLarge: vocesSans(size: 17, height: 1.55),
      bodyMedium: vocesSans(size: 15, height: 1.5),
      labelLarge: vocesSans(size: 14.5, weight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: VocesColors.desk,
      foregroundColor: VocesColors.inkOnDesk,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: vocesDisplay(22, color: VocesColors.inkOnDesk),
    ),
    dividerColor: VocesColors.paperLine,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: vocesSans(size: 13, color: VocesColors.muted, weight: FontWeight.w600),
      hintStyle: vocesSans(size: 15, color: VocesColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: VocesColors.paperLine)),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: VocesColors.paperLine)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: VocesColors.cobalt, width: 2)),
      errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: VocesColors.crimson)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VocesColors.marigold,
        foregroundColor: VocesColors.ink,
        disabledBackgroundColor: VocesColors.marigold.withValues(alpha: 0.45),
        disabledForegroundColor: VocesColors.ink.withValues(alpha: 0.5),
        minimumSize: const Size(44, 44),
        textStyle: vocesSans(size: 14.5, weight: FontWeight.w700),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VocesColors.ink,
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: VocesColors.ink, width: 1.5),
        textStyle: vocesSans(size: 14, weight: FontWeight.w600),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VocesColors.cobalt,
        minimumSize: const Size(44, 44),
        textStyle: vocesSans(size: 14.5, weight: FontWeight.w700),
        shape: shape,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: VocesColors.mutedOnDesk, width: 1.5),
      labelStyle: vocesSans(size: 13, color: VocesColors.mutedOnDesk, weight: FontWeight.w600),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    focusColor: VocesColors.cobalt,
  );
}
