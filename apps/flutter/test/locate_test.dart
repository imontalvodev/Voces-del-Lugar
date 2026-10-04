import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/locate.dart';

void main() {
  const madrid = LatLng(40.4, -3.7);

  Future<LatLng?> run(String first, {String afterAsking = 'whileInUse', bool ask = true, List<String>? log}) {
    return resolveLocation(
      ask: ask,
      permission: () async => first,
      request: () async {
        log?.add('pide');
        return afterAsking;
      },
      read: () async => madrid,
    );
  }

  test('con permiso lee la posición', () async {
    expect(await run('whileInUse'), madrid);
  });

  test('sin permiso lo pide y respeta la respuesta', () async {
    expect(await run('denied', afterAsking: 'whileInUse'), madrid);
    expect(await run('denied', afterAsking: 'denied'), isNull);
  });

  test('al abrir el mapa no pide permiso, solo usa el que ya hay', () async {
    final log = <String>[];
    expect(await run('denied', ask: false, log: log), isNull);
    expect(log, isEmpty);
  });

  test('denegado para siempre no vuelve a preguntar', () async {
    final log = <String>[];
    expect(await run('deniedForever', log: log), isNull);
    expect(log, isEmpty);
  });
}
