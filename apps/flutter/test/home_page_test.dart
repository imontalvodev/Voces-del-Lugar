import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/home_page.dart';

Map<String, dynamic> storyJson(int i) => {
      'id': 's$i',
      'title': 'Historia $i',
      'body': 'Texto $i',
      'narrator_name': 'Carmen',
      'license': 'CC-BY-SA-4.0',
      'status': 'published',
      'category': 'anecdota',
      'place': {'id': 'p$i', 'name': 'Plaza $i', 'latitude': 40.40 + i / 100, 'longitude': -3.70 + i / 100},
      'media': [],
    };

Future<void> pumpHome(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = VocesApi(
    client: MockClient((_) async => http.Response(jsonEncode([for (var i = 0; i < 6; i++) storyJson(i)]), 200)),
  );
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomePage(api: api, onLeaveStory: () {}, onOpenMap: () {}))));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('en una ventana baja el aviso de las luces no tapa los botones ni queda tras el dock', (tester) async {
    await pumpHome(tester, const Size(1280, 577));
    final hint = find.textContaining('Cada luz es una');
    if (hint.evaluate().isNotEmpty) {
      final rect = tester.getRect(hint);
      expect(rect.top, greaterThanOrEqualTo(tester.getRect(find.text('Abrir el mapa')).bottom + 8));
      expect(rect.bottom, lessThanOrEqualTo(577 - 100), reason: 'el dock ocupa el fondo de la ventana');
    }
    await settle(tester);
  });

  testWidgets('si el héroe cabe, el aviso explica qué son las luces', (tester) async {
    await pumpHome(tester, const Size(1440, 1100));
    expect(find.textContaining('Cada luz es una de las 6 historias'), findsOneWidget);
    await settle(tester);
  });
}
