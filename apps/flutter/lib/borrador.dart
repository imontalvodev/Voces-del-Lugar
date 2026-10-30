import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lo que lleva escrito el asistente «Contar», guardado en el dispositivo en
/// cada paso para no perder nada si se cierra la app.
class Borrador {
  Borrador({
    this.lat,
    this.lng,
    this.sitio = '',
    this.modo = 'grabar',
    this.titulo = '',
    this.tipo,
    this.epoca = '',
    this.texto = '',
    this.narrador = '',
    this.parentesco = '',
    this.fallecido = false,
    this.permiso = false,
    this.licencia = 'CC-BY-SA-4.0',
    this.paso = 1,
    this.audioRuta,
    this.audioSegundos,
  });

  double? lat;
  double? lng;
  String sitio;

  /// «grabar», «escribir» o «adjuntar».
  String modo;
  String titulo;
  String? tipo;
  String epoca;
  String texto;
  String narrador;
  String parentesco;
  bool fallecido;
  bool permiso;
  String licencia;
  int paso;

  /// En el móvil, la grabación ya hecha sigue en disco.
  String? audioRuta;
  int? audioSegundos;

  static const _clave = 'borrador_contar';

  bool get vacio =>
      lat == null && sitio.trim().isEmpty && titulo.trim().isEmpty && texto.trim().isEmpty && audioRuta == null;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'sitio': sitio,
    'modo': modo,
    'titulo': titulo,
    'tipo': tipo,
    'epoca': epoca,
    'texto': texto,
    'narrador': narrador,
    'parentesco': parentesco,
    'fallecido': fallecido,
    'permiso': permiso,
    'licencia': licencia,
    'paso': paso,
    'audioRuta': audioRuta,
    'audioSegundos': audioSegundos,
  };

  factory Borrador.fromJson(Map<String, dynamic> j) => Borrador(
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    sitio: j['sitio'] as String? ?? '',
    modo: j['modo'] as String? ?? 'grabar',
    titulo: j['titulo'] as String? ?? '',
    tipo: j['tipo'] as String?,
    epoca: j['epoca'] as String? ?? '',
    texto: j['texto'] as String? ?? '',
    narrador: j['narrador'] as String? ?? '',
    parentesco: j['parentesco'] as String? ?? '',
    fallecido: j['fallecido'] as bool? ?? false,
    permiso: j['permiso'] as bool? ?? false,
    licencia: j['licencia'] as String? ?? 'CC-BY-SA-4.0',
    paso: (j['paso'] as int? ?? 1).clamp(1, 4),
    audioRuta: j['audioRuta'] as String?,
    audioSegundos: j['audioSegundos'] as int?,
  );

  static Future<Borrador?> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto == null) return null;
      final borrador = Borrador.fromJson(jsonDecode(texto) as Map<String, dynamic>);
      return borrador.vacio ? null : borrador;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(toJson()));
  }

  static Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }
}

/// «Años 50», «década de 1920», «1958» o «en el 68» → el año que entiende la
/// API. Si no se entiende, no se manda.
int? decadaDeEpoca(String texto) {
  final t = texto.toLowerCase();
  final completo = RegExp(r'\b(1[6-9]\d\d|20\d\d)\b').firstMatch(t);
  if (completo != null) return int.parse(completo.group(1)!);
  final corto = RegExp(r"(?:años|anos|año|en el|del)\s*'?(\d0|\d\d)\b").firstMatch(t);
  if (corto != null) return 1900 + int.parse(corto.group(1)!);
  return null;
}
