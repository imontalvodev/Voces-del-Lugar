import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/widgets/review_queue.dart';

StoryPin _pin(String title) {
  return StoryPin(
    id: '1',
    title: title,
    body: 'Texto',
    narratorName: 'José',
    license: 'CC-BY-SA-4.0',
    status: 'pending_review',
    category: 'anecdota',
    placeId: 'p',
    placeName: 'La plaza',
    point: const LatLng(40.4, -3.7),
    mediaUrls: const [],
  );
}

void main() {
  testWidgets('publicar avisa con esa historia', (tester) async {
    String? published;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewQueue(stories: [_pin('En cola')], onPublish: (story) => published = story.title, onReject: (_) {}),
        ),
      ),
    );
    await tester.tap(find.text('Publicar'));
    await tester.pump();
    expect(published, 'En cola');
  });
}
