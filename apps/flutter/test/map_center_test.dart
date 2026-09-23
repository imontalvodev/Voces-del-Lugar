import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/pages/map_page.dart';

void main() {
  test('la posición de quien consulta abre más cerca que una ciudad buscada', () {
    expect(zoomForDevice, 14);
    expect(zoomForPlace, 13);
    expect(fallbackCenter, const LatLng(40.416, -3.703));
  });
}
