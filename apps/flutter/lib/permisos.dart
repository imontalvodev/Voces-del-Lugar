import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cómo está un permiso: dado, se puede preguntar o se negó para siempre
/// (entonces solo se da desde Ajustes).
enum EstadoPermiso { concedido, preguntable, denegado }

EstadoPermiso estadoDe(PermissionStatus estado) {
  if (estado.isGranted || estado.isLimited) return EstadoPermiso.concedido;
  if (estado.isPermanentlyDenied || estado.isRestricted) return EstadoPermiso.denegado;
  return EstadoPermiso.preguntable;
}

Future<EstadoPermiso> permisoMicro() async {
  if (kIsWeb) return EstadoPermiso.preguntable;
  try {
    return estadoDe(await Permission.microphone.status);
  } catch (_) {
    return EstadoPermiso.preguntable;
  }
}

/// Pide el micrófono. En Android pide también los avisos (desde Android 13
/// hacen falta) para que la notificación fija de «Grabando» se vea con el
/// móvil bloqueado; si se niegan, la grabación sigue igual.
Future<EstadoPermiso> pedirMicro() async {
  if (kIsWeb) return EstadoPermiso.preguntable;
  try {
    final micro = estadoDe(await Permission.microphone.request());
    if (micro == EstadoPermiso.concedido && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }
    return micro;
  } catch (_) {
    return EstadoPermiso.preguntable;
  }
}

/// Los Ajustes del sistema de esta app, para dar a mano un permiso negado.
Future<void> abrirAjustesApp() async {
  try {
    await openAppSettings();
  } catch (_) {}
}
