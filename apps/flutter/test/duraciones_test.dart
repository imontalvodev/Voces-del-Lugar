import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/duraciones.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/ficha.dart';

StoryPin _historia({int? segundos}) => StoryPin.fromJson({
  'id': 'a',
  'title': 'La fuente',
  'license': 'CC-BY-SA-4.0',
  'status': 'published',
  'place': {'id': 'p', 'name': 'Plaza Mayor', 'latitude': 41.8, 'longitude': -2.4},
  'media': [
    {'id': 'm1', 'url': '/api/v1/media/m1', 'duration_seconds': segundos, 'media_type': 'audio', 'processing_status': 'done'},
  ],
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Duraciones.olvidar();
  });

  test('lo medido se guarda en el dispositivo y vuelve al abrir la app', () async {
    final historia = _historia();
    expect(historia.segundosAudio, isNull);
    await Duraciones.guardar(historia.mediaUrls.first, const Duration(seconds: 89, milliseconds: 600));
    expect(historia.segundosAudio, 90);

    Duraciones.olvidar();
    expect(historia.segundosAudio, isNull);
    await Duraciones.cargar();
    expect(historia.segundosAudio, 90);
  });

  test('si la API la da, manda la API', () async {
    final historia = _historia(segundos: 200);
    await Duraciones.guardar(historia.mediaUrls.first, const Duration(seconds: 5));
    expect(historia.segundosAudio, 200);
  });

  testWidgets('la ficha enseña la duración medida', (tester) async {
    final historia = _historia();
    await Duraciones.guardar(historia.mediaUrls.first, const Duration(seconds: 89));
    await tester.pumpWidget(
      MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        home: Scaffold(body: FichaHistoria.de(historia, onTap: () {})),
      ),
    );
    expect(find.text('Audio · 1:29'), findsOneWidget);
  });
}
