import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:voces/api.dart';
import 'package:voces/notis.dart';

/// Este móvil apuntado a los avisos, como lo pide la API.
class DispositivoPush {
  const DispositivoPush({required this.plataforma, required this.endpoint, this.p256dh, this.auth});

  /// `webpush` (UnifiedPush) o `apns`.
  final String plataforma;

  /// La URL del distribuidor o el token de APNs.
  final String endpoint;
  final String? p256dh;
  final String? auth;

  Map<String, dynamic> toJson() => {'platform': plataforma, 'endpoint': endpoint, 'p256dh': ?p256dh, 'auth': ?auth};

  factory DispositivoPush.fromJson(Map<String, dynamic> json) => DispositivoPush(
    plataforma: json['platform'] as String,
    endpoint: json['endpoint'] as String,
    p256dh: json['p256dh'] as String?,
    auth: json['auth'] as String?,
  );
}

enum ResultadoAvisos {
  activados,

  /// El sistema no deja enseñar avisos: se da desde Ajustes.
  sinPermiso,

  /// Android sin una app de avisos (ntfy u otra) que los reciba.
  sinDistribuidor,

  /// No se pudo apuntar: sin conexión o la API no respondió.
  fallo,
}

/// Lo que cambia según la plataforma: cómo se apunta el móvil, cómo llegan
/// los avisos y cómo se borra.
abstract class CanalPush {
  Future<void> iniciar({
    required bool activados,
    required String? vapid,
    required void Function(DispositivoPush dispositivo) alDispositivo,
    required void Function(Uint8List contenido) alMensaje,
    required void Function(String historia) alAbrir,
  });

  /// Pide permiso y apunta el móvil. [elegir] pregunta qué app de avisos
  /// usar cuando hay varias y ninguna es la de siempre.
  Future<(ResultadoAvisos, DispositivoPush?)> activar({
    required String? vapid,
    required Future<String?> Function(List<String> distribuidores) elegir,
  });

  Future<void> desactivar();
}

/// Avisos push sin Google: UnifiedPush en Android y APNs en iOS. Recuerda si
/// se pidieron y apunta el móvil a la cuenta con la que se entra.
class AvisosPush {
  AvisosPush({required this.api, required this.canal, Future<void> Function(Map<String, dynamic> aviso)? mostrar})
    : _mostrar = mostrar ?? mostrarAviso;

  /// La de la app; en las pruebas, la que se monte.
  static AvisosPush? instancia;

  final VocesApi api;

  /// Nulo donde no hay avisos (la web).
  final CanalPush? canal;
  final Future<void> Function(Map<String, dynamic> aviso) _mostrar;

  /// Abre una historia al tocar su aviso.
  void Function(String historia)? alAbrir;

  /// Si se pidieron los avisos en este móvil.
  final activos = ValueNotifier<bool>(false);

  DispositivoPush? _dispositivo;
  String? _vapid;

  static const _claveActivos = 'avisos_push';
  static const _claveDispositivo = 'avisos_dispositivo';
  static const _claveVapid = 'avisos_vapid';

  bool get disponible => canal != null;

  Future<void> iniciar() async {
    final canal = this.canal;
    if (canal == null) return;
    final prefs = await SharedPreferences.getInstance();
    activos.value = prefs.getBool(_claveActivos) ?? false;
    _vapid = prefs.getString(_claveVapid);
    final guardado = prefs.getString(_claveDispositivo);
    if (guardado != null) _dispositivo = DispositivoPush.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
    try {
      await canal.iniciar(
        activados: activos.value,
        vapid: _vapid,
        alDispositivo: _nuevoDispositivo,
        alMensaje: _mensaje,
        alAbrir: (historia) => alAbrir?.call(historia),
      );
    } catch (_) {
      // Sin avisos la app sigue igual.
    }
  }

  Future<ResultadoAvisos> activar({required Future<String?> Function(List<String> distribuidores) elegir}) async {
    final canal = this.canal;
    if (canal == null) return ResultadoAvisos.fallo;
    try {
      _vapid = await api.pushConfig();
    } catch (_) {
      // Sin clave también vale: los distribuidores no la exigen.
    }
    final (resultado, dispositivo) = await canal.activar(vapid: _vapid, elegir: elegir);
    if (resultado != ResultadoAvisos.activados || dispositivo == null) return resultado;
    try {
      if (api.account != null) await api.registerDevice(dispositivo.toJson());
    } catch (_) {
      return ResultadoAvisos.fallo;
    }
    await _guardar(dispositivo);
    activos.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveActivos, true);
    if (_vapid != null) await prefs.setString(_claveVapid, _vapid!);
    return ResultadoAvisos.activados;
  }

  Future<void> desactivar() async {
    await alSalir();
    try {
      await canal?.desactivar();
    } catch (_) {}
    activos.value = false;
    _dispositivo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveActivos);
    await prefs.remove(_claveDispositivo);
  }

  /// Con sesión nueva, el móvil pasa a avisar a esa cuenta.
  Future<void> alEntrar() async {
    final dispositivo = _dispositivo;
    if (!activos.value || dispositivo == null || api.account == null) return;
    try {
      await api.registerDevice(dispositivo.toJson());
    } catch (_) {}
  }

  /// Antes de cerrar la sesión: que no le lleguen al móvil los avisos de otro.
  Future<void> alSalir() async {
    final dispositivo = _dispositivo;
    if (dispositivo == null || api.account == null) return;
    try {
      await api.removeDevice(dispositivo.endpoint);
    } catch (_) {}
  }

  Future<void> _guardar(DispositivoPush dispositivo) async {
    _dispositivo = dispositivo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveDispositivo, jsonEncode(dispositivo.toJson()));
  }

  /// El distribuidor cambió la dirección: se guarda y se le dice a la API.
  Future<void> _nuevoDispositivo(DispositivoPush dispositivo) async {
    await _guardar(dispositivo);
    await alEntrar();
  }

  Future<void> _mensaje(Uint8List contenido) async {
    try {
      final aviso = jsonDecode(utf8.decode(contenido));
      if (aviso is Map<String, dynamic> && aviso['title'] is String) await _mostrar(aviso);
    } catch (_) {
      // Un aviso que no se entiende no se enseña.
    }
  }
}

/// Enseña un aviso que llegó por UnifiedPush. Al tocarlo, abre su historia.
Future<void> mostrarAviso(Map<String, dynamic> aviso) async {
  if (!await Notis.preparar()) return;
  final historia = aviso['story_id'] as String?;
  await Notis.plugin.show(
    id: (historia ?? aviso['title']).hashCode & 0x7fffffff,
    title: aviso['title'] as String,
    body: aviso['body'] as String?,
    payload: historia == null ? null : '${Notis.prefijoHistoria}$historia',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'avisos',
        'Avisos',
        channelDescription: 'Historias publicadas, por revisar o nuevas cerca de tus sitios.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
  );
}

/// Android: UnifiedPush. Hace falta una app de avisos (un distribuidor) en
/// el móvil, como ntfy; ella descifra lo que llega.
class CanalUnifiedPush implements CanalPush {
  Completer<DispositivoPush?>? _esperando;

  @override
  Future<void> iniciar({
    required bool activados,
    required String? vapid,
    required void Function(DispositivoPush dispositivo) alDispositivo,
    required void Function(Uint8List contenido) alMensaje,
    required void Function(String historia) alAbrir,
  }) async {
    Notis.alAbrir = alAbrir;
    await Notis.preparar();
    final hay = await UnifiedPush.initialize(
      onNewEndpoint: (endpoint, _) {
        final claves = endpoint.pubKeySet;
        final dispositivo = DispositivoPush(
          plataforma: 'webpush',
          endpoint: endpoint.url,
          p256dh: claves?.pubKey,
          auth: claves?.auth,
        );
        final esperando = _esperando;
        _esperando = null;
        if (esperando != null && !esperando.isCompleted) {
          esperando.complete(dispositivo);
        } else {
          alDispositivo(dispositivo);
        }
      },
      onRegistrationFailed: (_, _) {
        final esperando = _esperando;
        _esperando = null;
        if (esperando != null && !esperando.isCompleted) esperando.complete(null);
      },
      onMessage: (mensaje, _) => alMensaje(mensaje.content),
    );
    // Hay que volver a apuntarse en cada arranque con el mismo distribuidor.
    if (hay && activados) await UnifiedPush.register(vapid: vapid);
  }

  @override
  Future<(ResultadoAvisos, DispositivoPush?)> activar({
    required String? vapid,
    required Future<String?> Function(List<String> distribuidores) elegir,
  }) async {
    final android = Notis.plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final permiso = await android?.requestNotificationsPermission();
    if (permiso == false) return (ResultadoAvisos.sinPermiso, null);
    if (!await UnifiedPush.tryUseCurrentOrDefaultDistributor()) {
      final distribuidores = await UnifiedPush.getDistributors();
      if (distribuidores.isEmpty) return (ResultadoAvisos.sinDistribuidor, null);
      final elegido = distribuidores.length == 1 ? distribuidores.single : await elegir(distribuidores);
      if (elegido == null) return (ResultadoAvisos.fallo, null);
      await UnifiedPush.saveDistributor(elegido);
    }
    final esperando = _esperando = Completer<DispositivoPush?>();
    await UnifiedPush.register(vapid: vapid);
    final dispositivo = await esperando.future.timeout(const Duration(seconds: 30), onTimeout: () => null);
    return dispositivo == null ? (ResultadoAvisos.fallo, null) : (ResultadoAvisos.activados, dispositivo);
  }

  @override
  Future<void> desactivar() => UnifiedPush.unregister();
}

/// iOS: APNs, con un canal propio en AppDelegate.swift. El sistema enseña el
/// aviso; aquí solo llega el token y el toque.
class CanalApns implements CanalPush {
  CanalApns({MethodChannel? canal}) : _canal = canal ?? const MethodChannel('voces/apns');

  final MethodChannel _canal;

  @override
  Future<void> iniciar({
    required bool activados,
    required String? vapid,
    required void Function(DispositivoPush dispositivo) alDispositivo,
    required void Function(Uint8List contenido) alMensaje,
    required void Function(String historia) alAbrir,
  }) async {
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'abrir' && llamada.arguments is String) alAbrir(llamada.arguments as String);
    });
    final inicial = await _canal.invokeMethod<String>('historiaInicial');
    if (inicial != null) alAbrir(inicial);
    if (!activados) return;
    // El token puede cambiar: se pide otra vez en cada arranque.
    final token = await _canal.invokeMethod<String>('registrar');
    if (token != null) alDispositivo(DispositivoPush(plataforma: 'apns', endpoint: token));
  }

  @override
  Future<(ResultadoAvisos, DispositivoPush?)> activar({
    required String? vapid,
    required Future<String?> Function(List<String> distribuidores) elegir,
  }) async {
    try {
      final token = await _canal.invokeMethod<String>('registrar');
      if (token == null) return (ResultadoAvisos.sinPermiso, null);
      return (ResultadoAvisos.activados, DispositivoPush(plataforma: 'apns', endpoint: token));
    } on PlatformException {
      return (ResultadoAvisos.fallo, null);
    }
  }

  @override
  Future<void> desactivar() => _canal.invokeMethod<void>('olvidar');
}

/// El canal de esta plataforma, o nada en la web y el escritorio.
CanalPush? canalDeLaPlataforma() {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => CanalUnifiedPush(),
    TargetPlatform.iOS => CanalApns(),
    _ => null,
  };
}
