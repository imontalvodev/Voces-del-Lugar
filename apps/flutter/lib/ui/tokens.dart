import 'package:flutter/material.dart';

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

/// Títulos (provisional hasta rehacer las pantallas con el tema nuevo).
TextStyle display(double size, {Color color = Palette.bone, bool italic = false, double height = 1.02}) {
  return TextStyle(
    fontFamily: 'AtkinsonHyperlegibleNext',
    fontWeight: FontWeight.w800,
    fontSize: size,
    color: color,
    height: height,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: size > 40 ? -0.6 : -0.1,
  );
}

/// Texto corrido (provisional hasta rehacer las pantallas con el tema nuevo).
TextStyle text({
  double size = 15,
  Color color = Palette.bone,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  double spacing = 0,
}) {
  return TextStyle(
    fontFamily: 'AtkinsonHyperlegibleNext',
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

