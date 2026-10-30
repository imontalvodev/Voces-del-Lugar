import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/ficha.dart';

Map<String, dynamic> storyJson(int i, {String category = 'anecdota'}) => {
  'id': 's$i',
  'number': 140 + i,
  'title': 'Historia $i',
  'body': 'Texto $i',
  'narrator_name': 'Carmen',
  'narrator_relation': 'abuela',
  'license': 'CC-BY-SA-4.0',
  'status': 'published',
  'category': category,
  'place': {'id': 'p$i', 'name': 'Plaza $i', 'latitude': 40.40, 'longitude': -3.70},
  'media': [],
};

Future<void> _inicio(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) responder,
  Size ventana = const Size(412, 1600),
  VoidCallback? onLeaveStory,
}) async {
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = VocesApi(client: MockClient(responder));
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      home: Scaffold(
        body: HomePage(api: api, onLeaveStory: onLeaveStory ?? () {}, onOpenMap: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('titular, acciones y lo último publicado en fichas', (tester) async {
    var dejar = 0;
    await _inicio(
      tester,
      responder: (_) async => http.Response(jsonEncode([storyJson(1), storyJson(2, category: 'leyenda')]), 200),
      onLeaveStory: () => dejar++,
    );
    await tester.pumpAndSettle();
    expect(find.text('Las historias de cada sitio, contadas por quien las vivió.'), findsOneWidget);
    expect(find.text('Lo último que se ha publicado'), findsOneWidget);
    expect(find.byType(FichaHistoria), findsNWidgets(2));
    expect(find.text('Nº 0141'), findsOneWidget);
    await tester.tap(find.text('Dejar una historia'));
    expect(dejar, 1);
  });

  testWidgets('mientras carga enseña los bloques fijos', (tester) async {
    await _inicio(tester, responder: (_) => Future.delayed(const Duration(seconds: 1), () => http.Response('[]', 200)));
    await tester.pump();
    expect(find.byType(Cargando), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('filtrar por un tipo sin historias ofrece volver a todas', (tester) async {
    await _inicio(tester, responder: (_) async => http.Response(jsonEncode([storyJson(1)]), 200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leyenda'));
    await tester.tap(find.text('Leyenda'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay ninguna leyenda'), findsOneWidget);
    await tester.tap(find.text('Ver todas las historias'));
    await tester.pumpAndSettle();
    expect(find.byType(FichaHistoria), findsOneWidget);
  });

  testWidgets('sin conexión lo dice y deja volver a intentarlo', (tester) async {
    var intentos = 0;
    await _inicio(
      tester,
      responder: (_) async {
        intentos++;
        if (intentos == 1) throw http.ClientException('sin red');
        return http.Response(jsonEncode([storyJson(1)]), 200);
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay conexión'), findsOneWidget);
    await tester.tap(find.text('Volver a intentarlo'));
    await tester.pumpAndSettle();
    expect(find.byType(FichaHistoria), findsOneWidget);
  });

  testWidgets('sin ninguna historia invita a dejar la primera', (tester) async {
    await _inicio(tester, responder: (_) async => http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay ninguna historia'), findsOneWidget);
  });

  testWidgets('en escritorio las fichas van a dos columnas', (tester) async {
    await _inicio(
      tester,
      ventana: const Size(1440, 1400),
      responder: (_) async => http.Response(jsonEncode([storyJson(1), storyJson(2)]), 200),
    );
    await tester.pumpAndSettle();
    final a = tester.getTopLeft(find.byType(FichaHistoria).at(0));
    final b = tester.getTopLeft(find.byType(FichaHistoria).at(1));
    expect(a.dy, b.dy);
    expect(a.dx, lessThan(b.dx));
  });
}
