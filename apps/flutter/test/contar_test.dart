import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/borrador.dart';
import 'package:voces/pages/contar_page.dart';
import 'package:voces/permisos.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

class _Llamadas {
  final peticiones = <http.Request>[];
  var salidas = 0;
  var verLoHecho = 0;
}

Future<_Llamadas> _asistente(WidgetTester tester, {bool conCuenta = true}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final llamadas = _Llamadas();
  final api = VocesApi(
    client: MockClient((request) async {
      llamadas.peticiones.add(request);
      final cuerpo = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 'nueva',
          'number': 197,
          'title': cuerpo['title'] ?? 'Título',
          'narrator_name': cuerpo['narrator_name'],
          'narrator_relation': cuerpo['narrator_relation'],
          'narrator_deceased': cuerpo['narrator_deceased'] ?? false,
          'license': cuerpo['license'] ?? 'CC-BY-SA-4.0',
          'status': 'pending_review',
          'category': cuerpo['category'] ?? 'otro',
          'decade_approx': cuerpo['decade_approx'],
          'place': {'id': 'p', 'name': 'La fuente', 'latitude': 40.2, 'longitude': -3.7},
          'media': [],
        }),
        201,
      );
    }),
  );
  if (conCuenta) api.account = Account(token: 't', id: 'u1', displayName: 'Ana', role: 'contributor', email: 'a@b.c');
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        home: ContarPage(
          api: api,
          conTeselas: false,
          permisoMicro: () async => EstadoPermiso.concedido,
          onSalir: () => llamadas.salidas++,
          onVerLoHecho: () => llamadas.verLoHecho++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return llamadas;
}

Future<void> _pulsar(WidgetTester tester, String texto) async {
  final boton = find.text(texto).last;
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> _marcarSitio(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Un micrófono de mentira: «graba» en un archivo de verdad del directorio temporal.
class _MicroFalso extends RecordPlatform {
  _MicroFalso(this.dir);

  final Directory dir;
  String? ruta;
  var paradas = 0;

  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async => true;
  @override
  Future<void> start(String recorderId, RecordConfig config, {required String path}) async => ruta = path;
  @override
  Future<String?> stop(String recorderId) async {
    paradas++;
    final r = ruta;
    if (r != null) File(r).writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    return r;
  }

  @override
  Future<void> pause(String recorderId) async {}
  @override
  Future<void> resume(String recorderId) async {}
  @override
  Future<bool> isRecording(String recorderId) async => ruta != null;
  @override
  Future<bool> isPaused(String recorderId) async => false;
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Future<void> cancel(String recorderId) async {}
  @override
  Future<Amplitude> getAmplitude(String recorderId) async => Amplitude(current: -20, max: -10);
  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder encoder) async => true;
  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];
  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async => const Stream.empty();
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  void setOnConfigChanged(String recorderId, void Function(RecordConfig config)? handler) {}
}

void main() {
  testWidgets('el asistente completo guarda la historia con todo lo contado', (tester) async {
    final llamadas = await _asistente(tester);
    expect(find.text('¿Dónde pasó?'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 1 de 4: Sitio'), findsOneWidget);

    await _pulsar(tester, 'Siguiente: historia');
    expect(find.text('Marca en el mapa dónde pasó.'), findsOneWidget);
    expect(find.text('Escribe el nombre del sitio.'), findsOneWidget);

    await _marcarSitio(tester);
    expect(find.text('Sitio marcado. Si no es ahí, toca otra vez.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'La fuente');
    await _pulsar(tester, 'Siguiente: historia');

    expect(find.text('Cuéntala'), findsOneWidget);
    await _pulsar(tester, 'Siguiente: quién la cuenta');
    expect(find.text('Falta la historia: grábala, escríbela o sube un audio.'), findsOneWidget);
    expect(find.text('Ponle un título.'), findsOneWidget);
    expect(find.text('Elige un tipo.'), findsOneWidget);

    await _pulsar(tester, 'Escribir');
    await tester.enterText(find.byType(TextField).at(0), 'Aquel invierno se heló la fuente.');
    await tester.enterText(find.byType(TextField).at(1), 'La noche que se heló la fuente');
    await _pulsar(tester, 'Anécdota');
    await tester.enterText(find.byType(TextField).at(2), 'Años 50');
    await _pulsar(tester, 'Siguiente: quién la cuenta');

    expect(find.text('¿Quién la cuenta?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Carmen Ruiz');
    await tester.enterText(find.byType(TextField).at(1), 'abuela');
    await _pulsar(tester, 'Ya ha fallecido');
    await _pulsar(tester, 'Siguiente: permiso');

    expect(find.text('Quien cuenta la historia decide si se publica y cómo se puede usar.'), findsOneWidget);
    expect(find.text('El permiso lo da la familia'), findsOneWidget);
    expect(find.text('Su familia me ha dado permiso para publicarla'), findsOneWidget);
    await _pulsar(tester, 'Guardar la historia');
    expect(find.text('Marca la casilla para confirmar el permiso.'), findsOneWidget);
    expect(llamadas.peticiones, isEmpty);

    await _pulsar(tester, 'Su familia me ha dado permiso para publicarla');
    await _pulsar(tester, 'Guardar la historia');
    expect(find.text('Gracias. Tu historia está guardada.'), findsOneWidget);
    expect(find.text('EN REVISIÓN'), findsWidgets);

    final alta = llamadas.peticiones.single;
    final cuerpo = jsonDecode(alta.body) as Map<String, dynamic>;
    expect(alta.url.path, '/api/v1/stories');
    expect(cuerpo['title'], 'La noche que se heló la fuente');
    expect(cuerpo['body'], 'Aquel invierno se heló la fuente.');
    expect(cuerpo['category'], 'anecdota');
    expect(cuerpo['decade_approx'], 1950);
    expect(cuerpo['narrator_name'], 'Carmen Ruiz');
    expect(cuerpo['narrator_deceased'], isTrue);
    expect((cuerpo['place'] as Map)['name'], 'La fuente');
    expect(await Borrador.cargar(), isNull);

    await _pulsar(tester, 'Ver lo que he dejado');
    expect(llamadas.verLoHecho, 1);
  });

  testWidgets('cada paso se guarda en el borrador del dispositivo', (tester) async {
    await _asistente(tester);
    await _marcarSitio(tester);
    await tester.enterText(find.byType(TextField).last, 'El lavadero');
    await tester.pump(const Duration(milliseconds: 400));
    final borrador = await Borrador.cargar();
    expect(borrador!.sitio, 'El lavadero');
    expect(borrador.lat, isNotNull);
  });

  testWidgets('Atrás vuelve al paso anterior y en el primero pregunta antes de salir', (tester) async {
    final llamadas = await _asistente(tester);
    await _marcarSitio(tester);
    await tester.enterText(find.byType(TextField).last, 'La fuente');
    await _pulsar(tester, 'Siguiente: historia');
    expect(find.text('Cuéntala'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde pasó?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await _pulsar(tester, 'Seguir contando');
    expect(llamadas.salidas, 0);

    await _pulsar(tester, 'Salir');
    await _pulsar(tester, 'Salir y borrar lo que llevo');
    expect(llamadas.salidas, 1);
    expect(await Borrador.cargar(), isNull);
  });

  testWidgets('sin sesión, al guardar pide entrar sin perder lo contado', (tester) async {
    final llamadas = await _asistente(tester, conCuenta: false);
    await _marcarSitio(tester);
    await tester.enterText(find.byType(TextField).last, 'La fuente');
    await _pulsar(tester, 'Siguiente: historia');
    await _pulsar(tester, 'Escribir');
    await tester.enterText(find.byType(TextField).at(0), 'Texto');
    await tester.enterText(find.byType(TextField).at(1), 'Título');
    await _pulsar(tester, 'Leyenda');
    await _pulsar(tester, 'Siguiente: quién la cuenta');
    await _pulsar(tester, 'Siguiente: permiso');
    await _pulsar(tester, 'Quien la cuenta me ha dado permiso para publicarla');
    await _pulsar(tester, 'Guardar la historia');
    expect(find.text('Para dejar historias y ver en qué estado están.'), findsOneWidget);
    expect(llamadas.peticiones, isEmpty);
    await _pulsar(tester, 'Volver');
    expect(find.text('Quien cuenta la historia decide si se publica y cómo se puede usar.'), findsOneWidget);
  });

  testWidgets('si se vuelve atrás a mitad de grabar, lo grabado se termina y se guarda', (tester) async {
    final dir = Directory.systemTemp.createTempSync('voces-grabar');
    addTearDown(() => dir.deleteSync(recursive: true));
    final micro = _MicroFalso(dir);
    final antes = RecordPlatform.instance;
    RecordPlatform.instance = micro;
    addTearDown(() => RecordPlatform.instance = antes);
    const canal = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (_) async => dir.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));

    await _asistente(tester);
    await _marcarSitio(tester);
    await tester.enterText(find.byType(TextField).last, 'La fuente');
    await _pulsar(tester, 'Siguiente: historia');
    await tester.tap(find.bySemanticsLabel('Empezar a grabar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Grabando'), findsOneWidget);

    await tester.binding.handlePopRoute();
    // Parar y leer el archivo es E/S de verdad: se le deja tiempo real.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde pasó?'), findsOneWidget);
    expect(micro.paradas, 1);

    await _pulsar(tester, 'Siguiente: historia');
    expect(find.text('Grabación terminada'), findsOneWidget);
    final borrador = await Borrador.cargar();
    expect(borrador!.audioRuta, micro.ruta);
  });

  testWidgets('el lector dice una sola vez «¿Qué tipo de historia es?»', (tester) async {
    final semantica = tester.ensureSemantics();
    await _asistente(tester);
    await _marcarSitio(tester);
    await tester.enterText(find.byType(TextField).last, 'La fuente');
    await _pulsar(tester, 'Siguiente: historia');
    expect(find.bySemanticsLabel('¿Qué tipo de historia es?'), findsOneWidget);
    semantica.dispose();
  });
}
