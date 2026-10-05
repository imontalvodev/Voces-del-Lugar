import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/story_format.dart';

StoryPin pin({String id = 'abc', String title = 'La fuente', int? decade}) => StoryPin(
      id: id,
      title: title,
      body: 'Iban a por agua.',
      narratorName: 'Carmen',
      license: 'CC-BY-SA-4.0',
      status: 'published',
      category: 'anecdota',
      placeId: 'p1',
      placeName: 'Plaza',
      point: const LatLng(40.41, -3.70),
      mediaUrls: const [],
      decade: decade,
    );

/// Retira la pantalla y deja vencer los temporizadores de las animaciones.
Future<void> settleAnimations(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('enlaces a historias', () {
    test('cada historia tiene su dirección', () {
      expect(storyPath('abc'), '/historia/abc');
    });

    test('de la dirección se saca la historia', () {
      expect(storyIdFromPath('/historia/abc'), 'abc');
    });

    test('el enlace para compartir lleva la dirección desde la que se entró', () {
      expect(storyLink('abc', Uri.parse('https://littlepc:58063/mapa?x=1')), 'https://littlepc:58063/historia/abc');
    });

    test('lo que no es una historia no se confunde con una', () {
      for (final path in [null, '/', '/historia', '/historia/', '/historia/abc/mas', '/mapa']) {
        expect(storyIdFromPath(path), isNull, reason: '$path');
      }
    });

    test('solo las direcciones de historia generan una pantalla propia', () {
      expect(vocesRoute(const RouteSettings(name: '/historia/abc')), isNotNull);
      expect(vocesRoute(const RouteSettings(name: '/')), isNull);
      expect(vocesRoute(const RouteSettings(name: '/otra')), isNull);
    });
  });

  group('StoryLoader', () {
    testWidgets('abre la historia del enlace cuando llega', (tester) async {
      await tester.pumpWidget(MaterialApp(home: StoryLoader(id: 'abc', load: (_) async => pin(title: 'El sereno'), page: (s) => Text(s.title))));
      await tester.pump();
      expect(find.text('El sereno'), findsOneWidget);
      await settleAnimations(tester);
    });

    testWidgets('si la historia no está, lo dice y ofrece volver al inicio', (tester) async {
      await tester.pumpWidget(MaterialApp(home: StoryLoader(id: 'nada', load: (_) async => throw ApiException('No está esa historia'), page: (s) => Text(s.title))));
      await tester.pump();
      expect(find.text('Esta historia no está'), findsOneWidget);
      expect(find.text('Ir al inicio'), findsOneWidget);
      await settleAnimations(tester);
    });
  });

  group('época', () {
    test('las décadas del siglo XX se dicen como se dicen', () {
      expect(decadeLabel(1950), 'Años 50');
      expect(decadeLabel(1958), 'Años 50');
      expect(decadeLabel(1920), 'Años 20');
    });

    test('fuera de los años 20 a 90 se nombra la década entera', () {
      expect(decadeLabel(1910), 'Década de 1910');
      expect(decadeLabel(2004), 'Década de 2000');
    });

    test('sin época no se inventa ninguna', () {
      expect(decadeLabel(null), isNull);
    });

    test('la ficha trae la época que guardó la API', () {
      final story = StoryPin.fromJson({
        'id': 'a', 'title': 't', 'license': 'CC-BY-SA-4.0', 'status': 'published', 'decade_approx': 1947,
        'place': {'id': 'p', 'name': 'n', 'latitude': 1, 'longitude': 2},
      });
      expect(story.decade, 1947);
    });
  });
}
