import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';

void main() {
  testWidgets('la ficha publicada ofrece retirar si hay callback', (tester) async {
    var withdrawn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryPage(
          story: StoryPin(
            id: '1',
            title: 'Publicada',
            body: 'Texto',
            narratorName: 'José',
            license: 'CC-BY-SA-4.0',
            status: 'published',
            category: 'anecdota',
            placeId: 'p',
            placeName: 'La plaza',
            point: const LatLng(40.4, -3.7),
            mediaUrls: const [],
          ),
          onUnpublish: () async => withdrawn = true,
        ),
      ),
    );
    await tester.tap(find.text('Retirar del mapa'));
    await tester.pump();
    expect(withdrawn, isTrue);
  });
}
