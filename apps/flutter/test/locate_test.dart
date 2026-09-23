import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/locate.dart';

void main() {
  test('con permiso devuelve el punto leído', () async {
    final point = await resolveLocation(
      permission: () async => 'whileInUse',
      request: () async => 'denied',
      read: () async => const LatLng(39.47, -6.37),
    );
    expect(point, const LatLng(39.47, -6.37));
  });

  test('si niegan el permiso no hay punto', () async {
    final point = await resolveLocation(
      permission: () async => 'denied',
      request: () async => 'denied',
      read: () async => const LatLng(39.47, -6.37),
    );
    expect(point, isNull);
  });

  test('si el permiso es permanente no vuelve a pedirlo', () async {
    var asked = false;
    final point = await resolveLocation(
      permission: () async => 'deniedForever',
      request: () async {
        asked = true;
        return 'whileInUse';
      },
      read: () async => const LatLng(0, 0),
    );
    expect(asked, isFalse);
    expect(point, isNull);
  });
}
