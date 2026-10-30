import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/reproductor.dart';

Map<String, dynamic> _json({String status = 'published', bool deceased = false, String author = 'u9'}) => {
  'id': 's1',
  'number': 142,
  'title': 'La noche que se heló la fuente',
  'body': 'Aquel invierno bajó tanto el frío.\n\nPor la mañana los críos patinaban en el pilón.',
  'narrator_name': 'Carmen Ruiz',
  'narrator_relation': 'abuela',
  'narrator_deceased': deceased,
  'decade_approx': 1950,
  'license': 'CC-BY-SA-4.0',
  'status': status,
  'category': 'anecdota',
  'author_id': author,
  'author_name': 'Lucía Ortega',
  'place': {'id': 'p1', 'name': 'Plaza Mayor', 'latitude': 41.8, 'longitude': -2.4},
  'media': [],
};

Future<List<String>> _ficha(
  WidgetTester tester, {
  Map<String, dynamic>? json,
  String? rol,
  String userId = 'u1',
  Size ventana = const Size(412, 2400),
}) async {
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final llamadas = <String>[];
  var actual = json ?? _json();
  final api = VocesApi(
    client: MockClient((request) async {
      llamadas.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/unpublish')) actual = {...actual, 'status': 'pending_review'};
      if (request.url.path.endsWith('/publish')) actual = {...actual, 'status': 'published'};
      if (request.url.path.endsWith('/reject')) actual = {...actual, 'status': 'rejected'};
      return http.Response(jsonEncode(actual), 200);
    }),
  );
  if (rol != null) api.account = Account(token: 't', id: userId, displayName: 'Ana', role: rol, email: 'a@b.c');
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        home: StoryPage(story: StoryPin.fromJson(actual), conTeselas: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return llamadas;
}

void main() {
  testWidgets('la ficha enseña sus datos a máquina, lo que cuenta y la licencia en llano', (tester) async {
    await _ficha(tester);
    expect(find.text('Nº 0142'), findsOneWidget);
    expect(find.text('La noche que se heló la fuente'), findsOneWidget);
    for (final dato in ['Lugar', 'Tipo', 'Época', 'Contada por', 'Recogida por']) {
      expect(find.text(dato), findsOneWidget, reason: dato);
    }
    expect(find.text('Años 50'), findsOneWidget);
    expect(find.text('Carmen Ruiz, abuela'), findsOneWidget);
    expect(find.text('Lucía Ortega'), findsOneWidget);
    expect(find.text('Por la mañana los críos patinaban en el pilón.'), findsOneWidget);
    expect(find.textContaining('Compartir igual', findRichText: true), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('vocesdellugar.org/historia/s1'), findsOneWidget);
    expect(find.text('Dónde pasó'), findsOneWidget);
    expect(find.text('Herramientas de moderación'), findsNothing);
  });

  testWidgets('si el narrador falleció lleva el sello del permiso de la familia', (tester) async {
    await _ficha(tester, json: _json(deceased: true));
    expect(find.text('PERMISO DE LA FAMILIA'), findsOneWidget);
  });

  testWidgets('quien modera retira del mapa tras confirmarlo', (tester) async {
    final llamadas = await _ficha(tester, rol: 'curator');
    await tester.ensureVisible(find.text('Retirar del mapa'));
    await tester.tap(find.text('Retirar del mapa'));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar del mapa?'), findsOneWidget);
    await tester.tap(find.text('Sí, retirar del mapa'));
    await tester.pumpAndSettle();
    expect(llamadas, contains('POST /api/v1/stories/s1/unpublish'));
    expect(find.text('Retirada. Ya no está en el mapa.'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('quien modera publica una en revisión con su mensaje exacto', (tester) async {
    final llamadas = await _ficha(
      tester,
      rol: 'admin',
      json: _json(status: 'pending_review'),
    );
    expect(find.text('EN REVISIÓN'), findsOneWidget);
    await tester.ensureVisible(find.text('Publicar en el mapa'));
    await tester.tap(find.text('Publicar en el mapa'));
    await tester.pumpAndSettle();
    expect(find.text('¿Publicar en el mapa?'), findsOneWidget);
    await tester.tap(find.text('Sí, publicar en el mapa'));
    await tester.pumpAndSettle();
    expect(llamadas, contains('POST /api/v1/stories/s1/publish'));
    expect(find.text('Publicada. Ya está en el mapa.'), findsOneWidget);
  });

  testWidgets('rechazar pide confirmación y lo dice exactamente', (tester) async {
    await _ficha(
      tester,
      rol: 'admin',
      json: _json(status: 'pending_review'),
    );
    await tester.ensureVisible(find.text('Rechazar'));
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Rechazar esta historia?'), findsOneWidget);
    await tester.tap(find.text('Sí, rechazar'));
    await tester.pumpAndSettle();
    expect(find.text('Rechazada. No llegará al mapa.'), findsOneWidget);
  });

  testWidgets('quien la subió la corrige mientras está en revisión', (tester) async {
    await _ficha(
      tester,
      rol: 'contributor',
      userId: 'u9',
      json: _json(status: 'pending_review'),
    );
    expect(find.text('Corregir'), findsOneWidget);
    await tester.ensureVisible(find.text('Corregir'));
    await tester.tap(find.text('Corregir'));
    await tester.pumpAndSettle();
    expect(find.text('Corregir la historia'), findsOneWidget);
    expect(find.text('Guardar la corrección'), findsOneWidget);
  });

  testWidgets('«Esta historia no está» ofrece el mapa y el inicio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: vdlTheme(VdlColors.claro, Brightness.light), home: const HistoriaNoEsta()),
    );
    expect(find.text('Esta historia no está'), findsOneWidget);
    expect(find.text('Nº ----'), findsOneWidget);
    expect(find.text('Abrir el mapa'), findsOneWidget);
    expect(find.text('Ir al inicio'), findsOneWidget);
  });

  group('reproductor', () {
    Future<void> vista(
      WidgetTester tester,
      EstadoReproductor estado, {
      double velocidad = 1,
      List<Duration>? idas,
    }) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: vdlTheme(VdlColors.claro, Brightness.light),
          home: Scaffold(
            body: ReproductorVista(
              titulo: 'La fuente',
              estado: estado,
              posicion: const Duration(seconds: 62),
              duracion: const Duration(seconds: 252),
              velocidad: velocidad,
              onAlternar: () {},
              onIr: (d) => idas?.add(d),
              onVelocidad: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('dice en qué está, el tiempo y ofrece saltos de 10 s', (tester) async {
      final idas = <Duration>[];
      await vista(tester, EstadoReproductor.pausa, idas: idas);
      expect(find.text('En pausa'), findsOneWidget);
      expect(find.text('1:02 / 4:12'), findsOneWidget);
      await tester.tap(find.byTooltip('Atrás 10 segundos'));
      await tester.tap(find.byTooltip('Adelante 10 segundos'));
      expect(idas, [const Duration(seconds: 52), const Duration(seconds: 72)]);
    });

    testWidgets('el botón de 64 dice «Pausar» mientras suena', (tester) async {
      await vista(tester, EstadoReproductor.sonando);
      expect(find.text('Escuchando'), findsOneWidget);
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
    });

    test('las velocidades se escriben con coma', () {
      expect(velocidades.map(etiquetaVelocidad), ['1×', '0,75×', '1,25×']);
    });
  });
}
