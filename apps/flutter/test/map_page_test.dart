import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/placa_mapa.dart';

Map<String, dynamic> _historia(int i, {String place = 'plaza', String name = 'Plaza Mayor', bool audio = false}) => {
  'id': 's$i',
  'number': i,
  'title': 'Historia $i',
  'narrator_name': 'Carmen Ruiz',
  'narrator_relation': 'abuela',
  'decade_approx': 1950,
  'license': 'CC-BY-SA-4.0',
  'status': 'published',
  'category': 'anecdota',
  'place': {'id': place, 'name': name, 'latitude': 40.2, 'longitude': -3.7},
  'media': [
    if (audio) {'id': 'm$i', 'url': '/api/v1/media/m$i', 'duration_seconds': 252},
  ],
};

class _Llamadas {
  final pedidas = <bool>[];
  var permiso = 'denied';
  var ajustes = 0;
}

Future<_Llamadas> _mapa(
  WidgetTester tester, {
  List<Map<String, dynamic>> historias = const [],
  Size ventana = const Size(412, 915),
  bool sinRed = false,
  LatLng? posicion,
  String permiso = 'denied',
  List<Map<String, dynamic>> lugares = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final llamadas = _Llamadas()..permiso = permiso;
  final api = VocesApi(
    client: MockClient((request) async {
      if (sinRed) throw http.ClientException('sin red');
      if (request.url.path.endsWith('/geocode')) return http.Response(jsonEncode(lugares), 200);
      return http.Response(jsonEncode(historias), 200);
    }),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      home: Scaffold(
        body: MapPage(
          api: api,
          conTeselas: false,
          onLeaveStory: (_, [_]) {},
          permiso: () async => llamadas.permiso,
          abrirAjustes: () async => llamadas.ajustes++,
          locate: ({bool ask = true}) async {
            llamadas.pedidas.add(ask);
            return posicion;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return llamadas;
}

void main() {
  testWidgets('una placa por lugar con su recuento', (tester) async {
    await _mapa(
      tester,
      historias: [
        _historia(1),
        _historia(2),
        _historia(3, place: 'ancha', name: 'Calle Ancha'),
      ],
    );
    expect(find.byType(PlacaLugar), findsNWidgets(2));
    expect(find.bySemanticsLabel('Plaza Mayor: 2 historias'), findsOneWidget);
    expect(find.bySemanticsLabel('Calle Ancha: 1 historia'), findsOneWidget);
    expect(find.text('En esta vista '), findsNothing);
    expect(find.textContaining('En esta vista', findRichText: true), findsOneWidget);
    expect(find.text('Ver la lista'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('al tocar una placa se abre la vista previa y la lista del sitio', (tester) async {
    await _mapa(tester, historias: [_historia(1, audio: true), _historia(2)]);
    await tester.tap(find.byType(PlacaLugar));
    await tester.pumpAndSettle();
    expect(find.text('Plaza Mayor'), findsWidgets);
    expect(find.text('2 historias'), findsOneWidget);
    expect(find.text('Historia 1'), findsOneWidget);
    expect(find.text('Anécdota · Años 50 · Carmen Ruiz, abuela'), findsOneWidget);
    expect(find.text('Escuchar · 4:12'), findsOneWidget);
    await tester.tap(find.text('Ver las 2 historias de este sitio'));
    await tester.pumpAndSettle();
    expect(find.byType(FichaHistoria), findsNWidgets(2));
    await tester.tap(find.byTooltip('Cerrar la lista'));
    await tester.pumpAndSettle();
    expect(find.byType(FichaHistoria), findsNothing);
  });

  testWidgets('«Ver la lista» enseña las historias de la vista', (tester) async {
    await _mapa(
      tester,
      historias: [
        _historia(1),
        _historia(2, place: 'ancha', name: 'Calle Ancha'),
      ],
    );
    await tester.tap(find.text('Ver la lista'));
    await tester.pumpAndSettle();
    expect(find.byType(FichaHistoria), findsNWidgets(2));
  });

  testWidgets('sin conexión lo dice con «Volver a intentarlo»', (tester) async {
    await _mapa(tester, sinRed: true);
    expect(find.text('No hay conexión'), findsOneWidget);
    expect(find.text('Volver a intentarlo'), findsOneWidget);
  });

  testWidgets('«Aquí» explica antes de pedir la ubicación y respeta «Ahora no»', (tester) async {
    final llamadas = await _mapa(tester);
    await tester.tap(find.bySemanticsLabel('Ir a donde estoy'));
    await tester.pumpAndSettle();
    expect(find.text('Para llevarte a donde estás'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(llamadas.pedidas, isEmpty);
  });

  testWidgets('si se deniega, dice dónde dar permiso y ofrece abrir Ajustes', (tester) async {
    final llamadas = await _mapa(tester);
    await tester.tap(find.bySemanticsLabel('Ir a donde estoy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(llamadas.pedidas, [true]);
    expect(find.text('No sabemos dónde estás'), findsOneWidget);
    expect(find.textContaining('Ajustes › Aplicaciones › Voces del Lugar › Permisos › Ubicación'), findsOneWidget);
    await tester.tap(find.text('Abrir Ajustes'));
    expect(llamadas.ajustes, 1);
  });

  testWidgets('con el permiso ya dado no pregunta y avisa de que te enseña dónde estás', (tester) async {
    final llamadas = await _mapa(tester, permiso: 'whileInUse', posicion: const LatLng(41.8, -2.4));
    llamadas.pedidas.clear();
    await tester.tap(find.bySemanticsLabel('Ir a donde estoy'));
    await tester.pumpAndSettle();
    expect(find.text('Para llevarte a donde estás'), findsNothing);
    expect(llamadas.pedidas, [false]);
    expect(find.text('Te mostramos dónde estás.'), findsOneWidget);
  });

  testWidgets('buscar un lugar enseña los encontrados y elegir uno los cierra', (tester) async {
    await _mapa(
      tester,
      lugares: [
        {'label': 'Lavapiés, Centro, Madrid', 'latitude': 40.4, 'longitude': -3.7, 'kind': 'suburb'},
      ],
    );
    await tester.enterText(find.byType(TextField), 'Lav');
    await tester.pump();
    expect(find.text('Buscando lugares…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Lavapiés'), findsOneWidget);
    expect(find.text('Barrio · Centro, Madrid'), findsOneWidget);
    await tester.tap(find.text('Lavapiés'));
    await tester.pumpAndSettle();
    expect(find.text('Barrio · Centro, Madrid'), findsNothing);
  });

  testWidgets('tocar un sitio vacío ofrece contar su historia', (tester) async {
    await _mapa(tester);
    await tester.tapAt(const Offset(206, 450));
    // flutter_map espera por si es un doble toque antes de dar el toque simple.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Aquí todavía no hay historias'), findsOneWidget);
    expect(find.text('Contar la historia de este sitio'), findsOneWidget);
    expect(find.byType(PinNuevo), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(PinNuevo), findsNothing);
  });

  testWidgets('en escritorio, panel de 460 con las historias de la vista', (tester) async {
    await _mapa(tester, ventana: const Size(1440, 1000), historias: [_historia(1), _historia(2)]);
    expect(find.textContaining('Historias en esta vista', findRichText: true), findsOneWidget);
    expect(find.byType(FichaHistoria), findsNWidgets(2));
    expect(find.text('Ir a donde estoy'), findsOneWidget);
    expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
  });

  testWidgets('en escritorio sin historias explica cómo contar una', (tester) async {
    await _mapa(tester, ventana: const Size(1440, 1000));
    expect(find.text('Toca el mapa en el sitio donde pasó algo para contarlo.'), findsOneWidget);
  });
}
