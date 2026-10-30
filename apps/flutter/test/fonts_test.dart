import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, List<(String, int)>>> families() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
    return {
      for (final family in manifest.cast<Map<String, dynamic>>())
        family['family'] as String: [
          for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>())
            (font['asset'] as String, font['weight'] as int? ?? 400),
        ],
    };
  }

  test('Atkinson Hyperlegible Next va dentro de la app en 400, 700 y 800', () async {
    final atkinson = (await families())['AtkinsonHyperlegibleNext'];
    expect(atkinson, isNotNull);
    expect(atkinson!.map((f) => f.$2), containsAll([400, 700, 800]));
    for (final (asset, _) in atkinson) {
      expect(asset, startsWith('assets/fonts/'));
      expect(asset, endsWith('.ttf'));
    }
  });

  test('Courier Prime va dentro de la app en 400 y 700', () async {
    final courier = (await families())['CourierPrime'];
    expect(courier, isNotNull);
    expect(courier!.map((f) => f.$2), containsAll([400, 700]));
  });

  test('no quedan las letras del diseño anterior', () async {
    final names = (await families()).keys;
    expect(names.where((n) => n.contains('Bricolage') || n.contains('Instrument')), isEmpty);
  });

  test('ninguna letra se pide por red', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('google_fonts')));
  });
}
