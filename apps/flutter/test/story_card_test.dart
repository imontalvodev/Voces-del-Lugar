import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/ui/story_card.dart';

StoryPin story({String title = 'El sereno', int? decade = 1950, String status = 'published'}) => StoryPin(
      id: 's1',
      title: title,
      body: 'Mi abuelo llevaba las llaves de todos los portales. Por las noches daba palmas y él venía con el chuzo y el farol, silbando una copla que nadie más sabía.',
      narratorName: 'Julián Moreno',
      license: 'CC-BY-SA-4.0',
      status: status,
      category: 'oficio',
      placeId: 'p1',
      placeName: 'Calle del Pez',
      point: const LatLng(40.42, -3.70),
      mediaUrls: const [],
      decade: decade,
    );

Future<void> pumpCard(WidgetTester tester, StoryPin pin, {double width = 420, bool showStatus = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(width: width, height: StoryCard.extent, child: StoryCard(story: pin, showStatus: showStatus)),
      ),
    ),
  );
}

void main() {
  testWidgets('la tarjeta adelanta el principio del relato', (tester) async {
    await pumpCard(tester, story());
    expect(find.textContaining('Mi abuelo llevaba las llaves'), findsOneWidget);
  });

  testWidgets('la tarjeta dice de qué tipo es y de qué época', (tester) async {
    await pumpCard(tester, story());
    expect(find.text('Oficio'), findsOneWidget);
    expect(find.text('Años 50'), findsOneWidget);
  });

  testWidgets('sin época no muestra ninguna', (tester) async {
    await pumpCard(tester, story(decade: null));
    expect(find.textContaining('Años'), findsNothing);
  });

  testWidgets('en tus historias se ve además en qué estado están', (tester) async {
    await pumpCard(tester, story(status: 'pending_review'), showStatus: true);
    expect(find.text('En revisión'), findsOneWidget);
  });

  testWidgets('un título largo cabe en la tarjeta más estrecha sin desbordarse', (tester) async {
    await pumpCard(tester, story(title: 'La verbena de la Paloma del cincuenta y ocho, cuando se fue la luz'), width: 300, showStatus: true);
    expect(tester.takeException(), isNull);
  });
}
