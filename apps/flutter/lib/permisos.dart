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

Future<EstadoPermiso> pedirMicro() async {
  if (kIsWeb) return EstadoPermiso.preguntable;
  try {
    return estadoDe(await Permission.microphone.request());
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
