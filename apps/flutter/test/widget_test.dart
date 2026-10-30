import 'package:flutter_test/flutter_test.dart';
import 'package:voces/api.dart';

void main() {
  group('defaultApiBase', () {
    test('fuera del navegador la API está en esta máquina', () {
      expect(defaultApiBase(Uri.parse('file:///app')), 'http://localhost:8001');
    });

    test('en web la API está en la misma máquina que sirve la app', () {
      expect(defaultApiBase(Uri.parse('http://192.168.1.40:8080/#/')), 'http://192.168.1.40:8001');
    });

    test('por HTTPS la API va por el mismo origen, detrás del proxy', () {
      expect(defaultApiBase(Uri.parse('https://192.168.1.40:8443/')), 'https://192.168.1.40:8443');
      expect(defaultApiBase(Uri.parse('https://voces.example.org/')), 'https://voces.example.org');
    });
  });

  group('resolveApiBase', () {
    test('origin usa la misma dirección que sirve la app, también por HTTP', () {
      expect(resolveApiBase('origin', Uri.parse('http://littlepc:58062/')), 'http://littlepc:58062');
    });

    test('una dirección explícita manda sobre la de la página', () {
      expect(resolveApiBase('http://api.casa:9000', Uri.parse('http://littlepc:58062/')), 'http://api.casa:9000');
    });

    test('sin valor se adivina como siempre', () {
      expect(resolveApiBase('', Uri.parse('http://192.168.1.40:8080/')), 'http://192.168.1.40:8001');
    });
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
}
