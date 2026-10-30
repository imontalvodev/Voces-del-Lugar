import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/avisos_push.dart';
import 'package:voces/notis.dart';

import 'apoyo/canal_falso.dart';

(VocesApi, List<http.Request>) _api({bool conCuenta = true}) {
  final peticiones = <http.Request>[];
  final api = VocesApi(
    client: MockClient((r) async {
      peticiones.add(r);
      if (r.url.path.endsWith('/push/config')) return http.Response(jsonEncode({'vapid_public_key': 'BP4z'}), 200);
      return http.Response('', 204);
    }),
  );
  if (conCuenta) api.account = Account(token: 't', id: 'u1', displayName: 'Ana', role: 'contributor', email: 'a@b.c');
  return (api, peticiones);
}

Future<String?> _ninguno(List<String> _) async => null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('al activarlos, el móvil se apunta a la cuenta con la clave VAPID de la API', () async {
    final (api, peticiones) = _api();
    final canal = CanalFalso();
    final avisos = AvisosPush(api: api, canal: canal);
    await avisos.iniciar();

    expect(await avisos.activar(elegir: _ninguno), ResultadoAvisos.activados);
    expect(canal.vapidPedida, 'BP4z');
    expect(avisos.activos.value, isTrue);
    final alta = peticiones.last;
    expect('${alta.method} ${alta.url.path}', 'PUT /api/v1/push/devices');
    expect(jsonDecode(alta.body), {'platform': 'webpush', 'endpoint': movilFalso.endpoint, 'p256dh': 'BCV', 'auth': 'BTB'});

    final otraVez = AvisosPush(api: api, canal: CanalFalso());
    await otraVez.iniciar();
    expect(otraVez.activos.value, isTrue, reason: 'se recuerda al volver a abrir la app');
  });

  test('sin app de avisos o sin permiso lo dice y no apunta nada', () async {
    for (final resultado in [ResultadoAvisos.sinDistribuidor, ResultadoAvisos.sinPermiso]) {
      final (api, peticiones) = _api();
      final avisos = AvisosPush(api: api, canal: CanalFalso(resultado: resultado));
      await avisos.iniciar();
      expect(await avisos.activar(elegir: _ninguno), resultado);
      expect(avisos.activos.value, isFalse);
      expect(peticiones.where((r) => r.method == 'PUT'), isEmpty);
    }
  });

  test('al salir de la cuenta el móvil se borra, y al entrar con otra se apunta a ella', () async {
    final (api, peticiones) = _api();
    final avisos = AvisosPush(api: api, canal: CanalFalso());
    await avisos.iniciar();
    await avisos.activar(elegir: _ninguno);

    await avisos.alSalir();
    final baja = peticiones.last;
    expect('${baja.method} ${baja.url.path}', 'DELETE /api/v1/push/devices');
    expect(baja.url.queryParameters['endpoint'], movilFalso.endpoint);

    api.account = Account(token: 't2', id: 'u2', displayName: 'Luis', role: 'contributor', email: 'l@b.c');
    await avisos.alEntrar();
    expect(peticiones.last.method, 'PUT');
    expect(peticiones.last.headers['Authorization'], 'Bearer t2');
  });

  test('si el distribuidor cambia la dirección, se le dice a la API', () async {
    final (api, peticiones) = _api();
    final canal = CanalFalso();
    final avisos = AvisosPush(api: api, canal: canal);
    await avisos.iniciar();
    await avisos.activar(elegir: _ninguno);
    canal.dispositivoNuevo(const DispositivoPush(plataforma: 'webpush', endpoint: 'https://ntfy.sh/upB', p256dh: 'X', auth: 'Y'));
    await pumpEventQueue();
    expect(jsonDecode(peticiones.last.body)['endpoint'], 'https://ntfy.sh/upB');
  });

  test('dejar de recibirlos borra el móvil de la API y del distribuidor', () async {
    final (api, peticiones) = _api();
    final canal = CanalFalso();
    final avisos = AvisosPush(api: api, canal: canal);
    await avisos.iniciar();
    await avisos.activar(elegir: _ninguno);
    await avisos.desactivar();
    expect(peticiones.last.method, 'DELETE');
    expect(canal.bajas, 1);
    expect(avisos.activos.value, isFalse);
  });

  test('lo que llega se enseña y al tocarlo abre su historia', () async {
    final (api, _) = _api();
    final canal = CanalFalso();
    final mostrados = <Map<String, dynamic>>[];
    final abiertas = <String>[];
    final avisos = AvisosPush(api: api, canal: canal, mostrar: (aviso) async => mostrados.add(aviso))
      ..alAbrir = abiertas.add;
    await avisos.iniciar();

    final aviso = {'kind': 'published', 'story_id': 'h1', 'title': 'Tu historia ya está en el mapa', 'body': '«La fuente» se ha publicado.'};
    canal.mensaje(Uint8List.fromList(utf8.encode(jsonEncode(aviso))));
    canal.mensaje(Uint8List.fromList(utf8.encode('esto no es json')));
    await pumpEventQueue();
    expect(mostrados, [aviso]);

    canal.abrir('h1');
    expect(abiertas, ['h1']);
  });

  test('sin canal (la web) no hay avisos', () async {
    final (api, peticiones) = _api();
    final avisos = AvisosPush(api: api, canal: null);
    await avisos.iniciar();
    expect(avisos.disponible, isFalse);
    expect(await avisos.activar(elegir: _ninguno), ResultadoAvisos.fallo);
    expect(peticiones, isEmpty);
  });

  test('el toque en una notificación reparte: botones a grabar, avisos a su historia', () {
    final botones = <String>[];
    final abiertas = <String>[];
    Notis.alBoton = botones.add;
    Notis.alAbrir = abiertas.add;
    const accion = NotificationResponseType.selectedNotificationAction;
    const toque = NotificationResponseType.selectedNotification;
    Notis.responder(const NotificationResponse(notificationResponseType: accion, actionId: 'pausar'));
    Notis.responder(const NotificationResponse(notificationResponseType: toque, payload: 'historia:h9'));
    Notis.responder(const NotificationResponse(notificationResponseType: toque, payload: 'otra cosa'));
    expect(botones, ['pausar']);
    expect(abiertas, ['h9']);
  });

  test('iOS: el token de APNs es el dispositivo y el toque abre la historia', () async {
    const canalNativo = MethodChannel('voces/apns');
    final llamadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canalNativo, (call) async {
      llamadas.add(call.method);
      return switch (call.method) {
        'registrar' => 'a1b2' * 16,
        'historiaInicial' => 'h7',
        _ => null,
      };
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canalNativo, null),
    );
    final abiertas = <String>[];
    final canal = CanalApns(canal: canalNativo);
    await canal.iniciar(
      activados: false,
      vapid: null,
      alDispositivo: (_) {},
      alMensaje: (_) {},
      alAbrir: abiertas.add,
    );
    expect(abiertas, ['h7']);
    final (resultado, dispositivo) = await canal.activar(vapid: null, elegir: _ninguno);
    expect(resultado, ResultadoAvisos.activados);
    expect(dispositivo!.toJson(), {'platform': 'apns', 'endpoint': 'a1b2' * 16});
    expect(llamadas, ['historiaInicial', 'registrar']);
  });
}
