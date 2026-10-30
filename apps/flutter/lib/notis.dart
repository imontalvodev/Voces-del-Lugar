import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Las notificaciones locales de Android, compartidas: la fija de «Grabando»
/// y los avisos que llegan por UnifiedPush. El plugin solo admite un
/// receptor de toques, así que aquí se reparte: los botones van a quien
/// graba y el toque en un aviso abre su historia.
class Notis {
  Notis._();

  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _listo;

  /// Botones de la notificación de grabar («pausar», «seguir», «terminar»).
  static void Function(String accion)? alBoton;

  /// Toque en un aviso: el id de la historia.
  static void Function(String historia)? alAbrir;

  /// Historia del aviso con el que se abrió la app, si fue así.
  static String? historiaInicial;

  static const prefijoHistoria = 'historia:';

  static bool get android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> preparar() {
    if (!android) return Future.value(false);
    return _listo ??= _iniciar();
  }

  static Future<bool> _iniciar() async {
    try {
      await plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: responder,
      );
      final inicio = await plugin.getNotificationAppLaunchDetails();
      if (inicio?.didNotificationLaunchApp ?? false) {
        historiaInicial = historiaDe(inicio!.notificationResponse?.payload);
      }
      return true;
    } catch (_) {
      _listo = null;
      return false;
    }
  }

  @visibleForTesting
  static void responder(NotificationResponse respuesta) {
    final accion = respuesta.actionId;
    if (accion != null) {
      alBoton?.call(accion);
      return;
    }
    final historia = historiaDe(respuesta.payload);
    if (historia != null) alAbrir?.call(historia);
  }

  static String? historiaDe(String? payload) {
    if (payload == null || !payload.startsWith(prefijoHistoria)) return null;
    final id = payload.substring(prefijoHistoria.length);
    return id.isEmpty ? null : id;
  }
}
