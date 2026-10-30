import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

/// Tabla de color de docs/rediseno/SPEC.md: token, claro, oscuro.
const _tabla = <String, (int, int)>{
  'cal': (0xFFF5F6F3, 0xFF11141C),
  'azulejo': (0xFFFFFFFF, 0xFF1A1F2B),
  'ficha': (0xFFF7F8F4, 0xFF161A24),
  'tinta': (0xFF1B1F2A, 0xFFE9EBF2),
  'piedra': (0xFF5A6070, 0xFFA9B0C2),
  'filete': (0xFFC9CDD6, 0xFF343B4D),
  'anil': (0xFF2638A8, 0xFF9DAAF2),
  'anilHondo': (0xFF18246E, 0xFFC3CBF7),
  'anilVelo': (0xFFE6E9F7, 0xFF252C45),
  'ocre': (0xFFE0A22B, 0xFFF0B847),
  'ocreTinta': (0xFF8A5A00, 0xFFF0B847),
  'carmin': (0xFFA3203A, 0xFFF08A9A),
  'verde': (0xFF2F6B4F, 0xFF7CC4A0),
  'sombraBoton': (0xFF18246E, 0xFF05070B),
};

Map<String, Color> _tokens(VdlColors c) => {
      'cal': c.cal,
      'azulejo': c.azulejo,
      'ficha': c.ficha,
      'tinta': c.tinta,
      'piedra': c.piedra,
      'filete': c.filete,
      'anil': c.anil,
      'anilHondo': c.anilHondo,
      'anilVelo': c.anilVelo,
      'ocre': c.ocre,
      'ocreTinta': c.ocreTinta,
      'carmin': c.carmin,
      'verde': c.verde,
      'sombraBoton': c.sombraBoton,
    };

void main() {
  test('los colores claros coinciden con la tabla del diseño', () {
    final claro = _tokens(VdlColors.claro);
    for (final MapEntry(key: token, value: (hex, _)) in _tabla.entries) {
      expect(claro[token], Color(hex), reason: token);
    }
  });

  test('los colores oscuros coinciden con la tabla del diseño', () {
    final oscuro = _tokens(VdlColors.oscuro);
    for (final MapEntry(key: token, value: (_, hex)) in _tabla.entries) {
      expect(oscuro[token], Color(hex), reason: token);
    }
  });

  for (final (nombre, c, b, sobre) in [
    ('claro', VdlColors.claro, Brightness.light, const Color(0xFFFFFFFF)),
    ('oscuro', VdlColors.oscuro, Brightness.dark, VdlColors.oscuro.cal),
  ]) {
    test('el ColorScheme $nombre sale de los tokens', () {
      final theme = vdlTheme(c, b);
      final scheme = theme.colorScheme;
      expect(scheme.brightness, b);
      expect(scheme.primary, c.anil);
      expect(scheme.onPrimary, sobre);
      expect(scheme.secondary, c.ocre);
      expect(scheme.error, c.carmin);
      expect(scheme.onError, sobre);
      expect(scheme.surface, c.azulejo);
      expect(scheme.onSurface, c.tinta);
      expect(scheme.surfaceContainerHighest, c.ficha);
      expect(scheme.outline, c.tinta);
      expect(scheme.outlineVariant, c.filete);
      expect(theme.scaffoldBackgroundColor, c.cal);
      expect(theme.extension<VdlColors>(), c);
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('la letra $nombre es Atkinson con la escala del diseño', () {
      final text = vdlTheme(c, b).textTheme;
      expect(text.bodyMedium!.fontFamily, 'AtkinsonHyperlegibleNext');
      expect(text.displaySmall!.fontSize, 44);
      expect(text.headlineMedium!.fontSize, 34);
      expect(text.titleLarge!.fontSize, 23);
      expect(text.titleMedium!.fontSize, 21);
      expect(text.bodyLarge!.fontSize, 19);
      expect(text.bodyMedium!.fontSize, 18);
      expect(text.bodySmall!.fontSize, 16);
      expect(text.labelLarge!.fontWeight, FontWeight.w800);
      expect(text.bodyMedium!.color, c.tinta);
    });
  }

  test('la sombra de placa es sólida', () {
    final sombra = sombraPlaca(VdlColors.claro, 3);
    expect(sombra.blurRadius, 0);
    expect(sombra.offset, const Offset(3, 3));
    expect(sombra.color, VdlColors.claro.sombraBoton);
  });

  test('la letra de registro es Courier Prime', () {
    expect(registro.fontFamily, 'CourierPrime');
  });
}
