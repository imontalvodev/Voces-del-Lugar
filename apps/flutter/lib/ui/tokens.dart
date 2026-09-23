import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta del crepúsculo: la hora en que se sacan las sillas a la puerta y se cuenta.
abstract final class Palette {
  static const deep = Color(0xFF110D20);
  static const night = Color(0xFF1C1631);
  static const plum = Color(0xFF3E2447);
  static const dusk = Color(0xFFC8786A);
  static const lamp = Color(0xFFF4BF72);
  static const ember = Color(0xFFE8935A);
  static const bone = Color(0xFFF2EADB);
  static const haze = Color(0xFFA99DB8);
  static const sage = Color(0xFFA6CDA9);
  static const alarm = Color(0xFFFF9C8A);

  static const glass = Color(0x14F2EADB);
  static const glassEdge = Color(0x26F2EADB);
  static const glassStrong = Color(0xCC1C1631);

  static const lampGlow = LinearGradient(colors: [lamp, ember], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

abstract final class Motion {
  static const quick = Duration(milliseconds: 180);
  static const settle = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 900);
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const out = Cubic(0.16, 1, 0.3, 1);

  static Duration of(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }
}

/// Instrument Serif para lo que se lee como un título de relato.
TextStyle display(double size, {Color color = Palette.bone, bool italic = false, double height = 1.02}) {
  return GoogleFonts.instrumentSerif(
    fontSize: size,
    color: color,
    height: height,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: size > 40 ? -0.6 : -0.1,
  );
}

/// Bricolage Grotesque para todo lo demás: cálida, algo imperfecta, legible.
TextStyle text({
  double size = 15,
  Color color = Palette.bone,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  double spacing = 0,
}) {
  return GoogleFonts.bricolageGrotesque(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData vocesTheme() {
  const radius = BorderRadius.all(Radius.circular(14));
  OutlineInputBorder edge(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Palette.night,
    colorScheme: const ColorScheme.dark(
      primary: Palette.lamp,
      onPrimary: Palette.deep,
      secondary: Palette.dusk,
      onSecondary: Palette.deep,
      surface: Palette.night,
      onSurface: Palette.bone,
      error: Palette.alarm,
      onError: Palette.deep,
    ),
    textTheme: GoogleFonts.bricolageGrotesqueTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: Palette.bone, displayColor: Palette.bone),
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.lamp,
      selectionColor: Palette.lamp.withValues(alpha: 0.3),
      selectionHandleColor: Palette.lamp,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0FF2EADB),
      labelStyle: text(size: 14, color: Palette.haze),
      floatingLabelStyle: text(size: 14, color: Palette.lamp, weight: FontWeight.w600),
      hintStyle: text(size: 15, color: Palette.haze.withValues(alpha: 0.7)),
      helperStyle: text(size: 12.5, color: Palette.haze),
      errorStyle: text(size: 12.5, color: Palette.alarm),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: edge(Palette.glassEdge),
      enabledBorder: edge(Palette.glassEdge),
      focusedBorder: edge(Palette.lamp, 1.6),
      errorBorder: edge(Palette.alarm),
      focusedErrorBorder: edge(Palette.alarm, 1.6),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.lamp,
        minimumSize: const Size(44, 44),
        textStyle: text(size: 15, weight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.deep : Palette.haze),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.lamp : Palette.glass),
      trackOutlineColor: WidgetStateProperty.all(Palette.glassEdge),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.lamp : Colors.transparent),
      checkColor: WidgetStateProperty.all(Palette.deep),
      side: const BorderSide(color: Palette.haze, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.plum,
      contentTextStyle: text(size: 14.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Palette.deep, borderRadius: BorderRadius.circular(8)),
      textStyle: text(size: 12.5),
    ),
    focusColor: Palette.lamp.withValues(alpha: 0.25),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
