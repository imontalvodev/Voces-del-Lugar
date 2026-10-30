// lib/theme/vdl_theme.dart
import 'package:flutter/material.dart';
import 'package:voces/theme/vdl_colors.dart';

ThemeData vdlTheme(VdlColors c, Brightness b) {
  const ui = 'AtkinsonHyperlegibleNext';
  final text = TextTheme(
    displaySmall:  TextStyle(fontFamily: ui, fontSize: 44, height: 1.12, fontWeight: FontWeight.w800), // display
    headlineMedium:TextStyle(fontFamily: ui, fontSize: 34, height: 1.12, fontWeight: FontWeight.w800), // titulo (28 en compacto)
    titleLarge:    TextStyle(fontFamily: ui, fontSize: 23, height: 1.2,  fontWeight: FontWeight.w800), // seccion
    titleMedium:   TextStyle(fontFamily: ui, fontSize: 21, height: 1.2,  fontWeight: FontWeight.w800), // tarjeta
    bodyLarge:     TextStyle(fontFamily: ui, fontSize: 19, height: 1.65),                              // lectura
    bodyMedium:    TextStyle(fontFamily: ui, fontSize: 18, height: 1.5),                               // cuerpo
    bodySmall:     TextStyle(fontFamily: ui, fontSize: 16, height: 1.5),                               // apoyo (mínimo)
    labelLarge:    TextStyle(fontFamily: ui, fontSize: 18, fontWeight: FontWeight.w800),               // botón grande
  ).apply(bodyColor: c.tinta, displayColor: c.tinta);

  final borde = BorderSide(color: c.tinta, width: 2);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.cal,
    colorScheme: ColorScheme(
      brightness: b,
      primary: c.anil, onPrimary: b == Brightness.light ? Colors.white : c.cal,
      secondary: c.ocre, onSecondary: c.tinta,
      error: c.carmin, onError: b == Brightness.light ? Colors.white : c.cal,
      surface: c.azulejo, onSurface: c.tinta,
      surfaceContainerHighest: c.ficha, outline: c.tinta, outlineVariant: c.filete,
    ),
    textTheme: text,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,          // el «hundido» de 2 px sustituye a la onda
    materialTapTargetSize: MaterialTapTargetSize.padded,
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56), padding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: text.labelLarge, backgroundColor: c.anil,
      disabledBackgroundColor: c.filete, disabledForegroundColor: c.piedra,
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 56), foregroundColor: c.anil, backgroundColor: c.azulejo,
      side: BorderSide(color: c.anil, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: text.labelLarge,
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.azulejo, contentPadding: const EdgeInsets.all(14),
      enabledBorder: OutlineInputBorder(borderSide: borde, borderRadius: BorderRadius.circular(2)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.anilHondo, width: 3), borderRadius: BorderRadius.circular(2)),
      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: c.carmin, width: 2), borderRadius: BorderRadius.circular(2)),
      errorStyle: TextStyle(color: c.carmin, fontWeight: FontWeight.w700, fontSize: 16),
      helperMaxLines: 3,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68, backgroundColor: c.azulejo, indicatorColor: c.anilVelo,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.azulejo, barrierColor: const Color(0x9E1B1F2A),
      shape: RoundedRectangleBorder(side: borde, borderRadius: BorderRadius.circular(4)),
    ),
  );
}

// Sombra sólida desplazada (sin blurRadius: barata en Flutter web)
BoxShadow sombraPlaca(VdlColors c, [double d = 2]) =>
    BoxShadow(color: c.sombraBoton, offset: Offset(d, d), blurRadius: 0);

// Courier Prime solo para datos de registro
const registro = TextStyle(fontFamily: 'CourierPrime', fontSize: 17, height: 1.45, fontWeight: FontWeight.w700);
