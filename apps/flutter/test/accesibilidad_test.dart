import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/bienvenida_page.dart';
import 'package:voces/pages/contar_page.dart';
import 'package:voces/pages/entrar_page.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/pages/revisar_page.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

Map<String, dynamic> _historia(String id, String status) => {
  'id': id,
  'number': 142,
  'title': 'La noche que se heló la fuente',
  'body': 'Aquel invierno bajó tanto el frío.',
  'narrator_name': 'Carmen Ruiz',
  'narrator_relation': 'abuela',
  'decade_approx': 1950,
  'license': 'CC-BY-SA-4.0',
  'status': status,
  'category': 'anecdota',
  'author_id': 'u9',
  'author_name': 'Lucía Ortega',
  'created_at': '2026-10-14T09:00:00Z',
  'place': {'id': 'p$id', 'name': 'Plaza Mayor', 'latitude': 41.8, 'longitude': -2.4},
  'media': [],
};

VocesApi _api({String? rol}) {
  final api = VocesApi(
    client: MockClient((request) async {
      final ruta = request.url.path;
      if (ruta.endsWith('/stories') || ruta.contains('/me/') || ruta.contains('/moderation')) {
        return http.Response(jsonEncode([_historia('a', 'published'), _historia('b', 'pending_review')]), 200);
      }
      return http.Response(jsonEncode(_historia('a', 'published')), 200);
    }),
  );
  if (rol != null) {
    api.account = Account(token: 't', id: 'u1', displayName: 'Lucía Ortega', role: rol, email: 'lucia@correo.es');
  }
  return api;
}

/// Cada pantalla, con su API de prueba.
final _pantallas = <String, Widget Function()>{
  'Bienvenida': () => BienvenidaPage(letra: PreferenciaLetra(TamanoLetra.normal), onEmpezar: () {}),
  'Inicio': () => HomePage(api: _api(), onLeaveStory: () {}, onOpenMap: () {}),
  'Ficha': () => StoryPage(story: StoryPin.fromJson(_historia('a', 'published')), conTeselas: false),
  'Ficha en revisión': () {
    final api = _api(rol: 'curator');
    return ApiScope(
      api: api,
      child: StoryPage(story: StoryPin.fromJson(_historia('b', 'pending_review')), conTeselas: false),
    );
  },
  'Entrar': () => EntrarPage(api: _api(), onHecho: () {}),
  'Crear cuenta': () => EntrarPage(api: _api(), crear: true, onHecho: () {}),
  'Cuenta': () => AccountPage(
    api: _api(rol: 'curator'),
    onChanged: () {},
    onLeaveStory: () {},
  ),
  'Moderación': () => RevisarPage(api: _api(rol: 'curator')),
  'Mapa': () => MapPage(
    api: _api(),
    conTeselas: false,
    onLeaveStory: (_, [_]) {},
    permiso: () async => 'denied',
    abrirAjustes: () async {},
    locate: ({bool ask = true}) async => null,
  ),
  'Barra de secciones': () => Armazon(
    seccion: Seccion.inicio,
    moderador: true,
    onSeccion: (_) {},
    paginas: {for (final s in Seccion.values) s: Center(child: Text('Página ${s.name}'))},
  ),
  'Contar': () {
    final api = _api(rol: 'contributor');
    return ContarPage(api: api, conTeselas: false, onSalir: () {}, onVerLoHecho: () {});
  },
};

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  required bool oscuro,
  TamanoLetra letra = TamanoLetra.normal,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _api();
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        darkTheme: vdlTheme(VdlColors.oscuro, Brightness.dark),
        themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => EscalaLetra(preferencia: PreferenciaLetra(letra), child: child!),
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (oscuro, letra) in [
    (false, TamanoLetra.normal),
    (true, TamanoLetra.normal),
    (false, TamanoLetra.muyGrande),
  ]) {
    final modo = '${oscuro ? 'oscuro' : 'claro'}${letra == TamanoLetra.normal ? '' : ' y Aa++'}';
    for (final MapEntry(key: nombre, value: crear) in _pantallas.entries) {
      testWidgets('$nombre en $modo: todo lo pulsable mide 48 y dice qué hace; el texto se lee', (tester) async {
        final semantica = tester.ensureSemantics();
        await _montar(tester, crear(), oscuro: oscuro, letra: letra);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  }

  /// Lo que lee TalkBack o VoiceOver, en orden.
  List<String> lectura(WidgetTester tester) => [
    for (final n in tester.semantics.simulatedAccessibilityTraversal())
      if (n.label.trim().isNotEmpty) n.label,
  ];

  for (final MapEntry(key: nombre, value: crear) in _pantallas.entries) {
    testWidgets('$nombre: el lector no repite lo mismo dos veces seguidas', (tester) async {
      final semantica = tester.ensureSemantics();
      await _montar(tester, crear(), oscuro: false);
      final leido = lectura(tester);
      for (var i = 0; i < leido.length; i++) {
        final partes = leido[i].split('\n').map((p) => p.trim().toLowerCase()).toList();
        expect(partes.toSet().length, partes.length, reason: 'repite dentro de «${leido[i]}»');
        if (i > 0) expect(leido[i], isNot(leido[i - 1]), reason: 'repite «${leido[i]}»');
      }
      semantica.dispose();
    });
  }

  testWidgets('la ficha se lee en orden: volver, número, título y datos', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, _pantallas['Ficha']!(), oscuro: false);
    final leido = lectura(tester);
    final orden = ['Volver', 'Nº 0142', 'La noche que se heló la fuente', 'Lugar', 'Plaza Mayor', 'Compartir'];
    final posiciones = [for (final t in orden) leido.indexOf(t)];
    expect(posiciones, everyElement(isNonNegative), reason: '$leido');
    expect([...posiciones]..sort(), posiciones, reason: '$leido');
    semantica.dispose();
  });

  testWidgets('el asistente dice en qué paso está antes de pedir nada', (tester) async {
    final semantica = tester.ensureSemantics();
    await _montar(tester, _pantallas['Contar']!(), oscuro: false);
    final leido = lectura(tester);
    expect(leido.indexOf('Paso 1 de 4: Sitio'), lessThan(leido.indexOf('¿Dónde pasó?')));
    expect(leido.last, 'Siguiente: historia');
    semantica.dispose();
  });
}
