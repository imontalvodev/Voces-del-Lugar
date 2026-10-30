import 'dart:typed_data';

import 'package:voces/avisos_push.dart';

const movilFalso = DispositivoPush(
  plataforma: 'webpush',
  endpoint: 'https://ntfy.sh/upA?up=1',
  p256dh: 'BCV',
  auth: 'BTB',
);

/// Un canal de avisos sin plataforma: contesta lo que se le diga.
class CanalFalso implements CanalPush {
  CanalFalso({this.resultado = ResultadoAvisos.activados});

  ResultadoAvisos resultado;
  String? vapidPedida;
  var bajas = 0;
  late void Function(DispositivoPush) dispositivoNuevo;
  late void Function(Uint8List) mensaje;
  late void Function(String) abrir;

  @override
  Future<void> iniciar({
    required bool activados,
    required String? vapid,
    required void Function(DispositivoPush dispositivo) alDispositivo,
    required void Function(Uint8List contenido) alMensaje,
    required void Function(String historia) alAbrir,
  }) async {
    dispositivoNuevo = alDispositivo;
    mensaje = alMensaje;
    abrir = alAbrir;
  }

  @override
  Future<(ResultadoAvisos, DispositivoPush?)> activar({
    required String? vapid,
    required Future<String?> Function(List<String> distribuidores) elegir,
  }) async {
    vapidPedida = vapid;
    return (resultado, resultado == ResultadoAvisos.activados ? movilFalso : null);
  }

  @override
  Future<void> desactivar() async => bajas++;
}
