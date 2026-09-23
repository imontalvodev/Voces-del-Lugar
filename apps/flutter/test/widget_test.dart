import 'package:flutter_test/flutter_test.dart';
import 'package:voces/api.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/voice_terrain.dart';

void main() {
  test('la API local es el valor por defecto', () {
    expect(apiBase, 'http://localhost:8001');
  });

  group('audioType', () {
    test('declara el tipo que el backend acepta para cada extensión', () {
      expect(audioType('grabacion.wav').mimeType, 'audio/wav');
      expect(audioType('grabacion.m4a').mimeType, 'audio/mp4');
      expect(audioType('Voz.MP3').mimeType, 'audio/mpeg');
      expect(audioType('nota.ogg').mimeType, 'audio/ogg');
      expect(audioType('nota.webm').mimeType, 'audio/webm');
    });

    test('lo desconocido queda como binario y el backend lo rechaza con su mensaje', () {
      expect(audioType('foto.jpg').mimeType, 'application/octet-stream');
    });
  });

  group('voiceLevels', () {
    test('la misma historia siempre tiene la misma huella', () {
      expect(voiceLevels('abc', 40), voiceLevels('abc', 40));
      expect(voiceLevels('abc', 40), isNot(voiceLevels('abd', 40)));
    });

    test('los niveles quedan entre 0.1 y 1', () {
      final levels = voiceLevels('una-historia-cualquiera', 64);
      expect(levels, hasLength(64));
      expect(levels.every((l) => l >= 0.1 && l <= 1.0), isTrue);
    });
  });

  group('beaconsFromPoints', () {
    test('el oeste queda a la izquierda y el norte al fondo', () {
      final beacons = beaconsFromPoints([
        (id: 'oeste-norte', lat: 40.43, lon: -3.72, label: 'a'),
        (id: 'este-sur', lat: 40.40, lon: -3.69, label: 'b'),
      ]);
      final west = beacons.firstWhere((b) => b.id == 'oeste-norte');
      final east = beacons.firstWhere((b) => b.id == 'este-sur');
      expect(west.x, lessThan(east.x));
      expect(west.z, lessThan(east.z));
    });

    test('sin historias no hay farolas', () {
      expect(beaconsFromPoints(const []), isEmpty);
    });
  });
}
