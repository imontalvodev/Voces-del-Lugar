import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/map_page.dart';

void main() {
  test('la posición de quien consulta abre más cerca que una ciudad buscada', () {
    expect(zoomForDevice, 14);
    expect(zoomForPlace, 13);
    expect(fallbackCenter, const LatLng(40.416, -3.703));
  });

  test('un lugar con dos historias es un solo punto', () {
    StoryPin pin(String id) {
      return StoryPin(
        id: id,
        title: id,
        body: null,
        narratorName: null,
        license: 'CC-BY-SA-4.0',
        status: 'published',
        category: 'anecdota',
        placeId: 'mismo',
        placeName: 'La plaza',
        point: const LatLng(40.4, -3.7),
        mediaUrls: const [],
      );
    }

    final pins = onePinPerPlace([pin('a'), pin('b')]);
    expect(pins.map((story) => story.id), ['a']);
  });
}
