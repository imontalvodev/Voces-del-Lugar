import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:voces/notis.dart';

/// En Android, grabar con el móvil bloqueado necesita un servicio en primer
/// plano con su notificación fija: «Grabando», el tiempo y los botones
/// Pausar y Terminar. En iOS basta el audio en segundo plano.
class AvisoGrabacion {
  AvisoGrabacion._();

  static final instancia = AvisoGrabacion._();

  static const _id = 7;
  FlutterLocalNotificationsPlugin get _notis => Notis.plugin;
  bool _listo = false;

  /// Lo que pide la notificación: «pausar», «seguir» o «terminar».
  final accion = ValueNotifier<String?>(null);

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _preparar() async {
    if (_listo || !_android) return;
    Notis.alBoton = (id) {
      accion.value = null;
      accion.value = id;
    };
    _listo = await Notis.preparar();
  }

  /// Enseña (o actualiza) la notificación fija. Con [pausada], sin cronómetro.
  Future<void> mostrar({required Duration llevado, required bool pausada}) async {
    if (!_android) return;
    try {
      await _preparar();
      final android = _notis.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.startForegroundService(
        id: _id,
        title: pausada ? 'En pausa · ${_tiempo(llevado)}' : 'Grabando',
        body: pausada
            ? 'Lo grabado está a salvo. Pulsa «Seguir» cuando quieras.'
            : 'Puedes bloquear el móvil. La grabación sigue.',
        foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeMicrophone},
        notificationDetails: AndroidNotificationDetails(
          'grabar',
          'Grabar',
          channelDescription: 'Aviso fijo mientras se graba una historia.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: !pausada,
          usesChronometer: !pausada,
          when: DateTime.now().subtract(llevado).millisecondsSinceEpoch,
          actions: [
            AndroidNotificationAction(
              pausada ? 'seguir' : 'pausar',
              pausada ? 'Seguir' : 'Pausar',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction('terminar', 'Terminar', showsUserInterface: true),
          ],
        ),
      );
    } catch (_) {
      // Sin notificación la grabación sigue mientras la app esté delante.
    }
  }

  Future<void> quitar() async {
    if (!_android || !_listo) return;
    try {
      await _notis
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    } catch (_) {}
  }

  static String _tiempo(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
