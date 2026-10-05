import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiBaseOverride = String.fromEnvironment('API_BASE');

/// Puerto en el que escucha la API cuando no se indica `API_BASE`.
const apiPort = 8001;

/// Sin `API_BASE`, la app web busca la API en la misma máquina que la sirve:
/// por HTTP en el puerto de la API; por HTTPS en el mismo origen, detrás del
/// proxy que sirve la app (el navegador no deja mezclar HTTPS con HTTP).
String defaultApiBase(Uri page) {
  if (page.scheme == 'https' && page.host.isNotEmpty) return page.origin;
  if (page.scheme == 'http' && page.host.isNotEmpty) return 'http://${page.host}:$apiPort';
  return 'http://localhost:$apiPort';
}

/// `API_BASE=origin` deja la API en la misma dirección que sirve la app, que es
/// lo que pasa detrás de un proxy en el que la web y `/api` comparten puerto.
String resolveApiBase(String override, Uri page) {
  if (override == 'origin') return page.origin;
  return override.isNotEmpty ? override : defaultApiBase(page);
}

final String apiBase = resolveApiBase(_apiBaseOverride, Uri.base);

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Account {
  Account({required this.token, required this.displayName, required this.role, required this.email, this.id = ''});
  final String token;
  final String id;
  final String displayName;
  final String role;
  final String email;
  bool get canModerate => role == 'admin' || role == 'curator';
}

class StoryPin {
  StoryPin({
    required this.id,
    required this.title,
    required this.body,
    required this.narratorName,
    required this.license,
    required this.status,
    required this.category,
    required this.placeId,
    required this.placeName,
    required this.point,
    required this.mediaUrls,
    this.authorId = '',
    this.narratorRelation,
  });

  final String id;
  final String title;
  final String? body;
  final String? narratorName;
  final String license;
  final String status;
  final String category;
  final String placeId;
  final String placeName;
  final LatLng point;
  final List<String> mediaUrls;
  final String authorId;
  final String? narratorRelation;

  bool get published => status == 'published';
  bool get pending => status == 'pending_review';

  factory StoryPin.fromJson(Map<String, dynamic> json) {
    final place = json['place'] as Map<String, dynamic>;
    final media = (json['media'] as List<dynamic>? ?? []);
    return StoryPin(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      narratorName: json['narrator_name'] as String?,
      license: json['license'] as String,
      status: json['status'] as String,
      category: json['category'] as String? ?? 'anecdota',
      placeId: place['id'] as String,
      placeName: place['name'] as String,
      point: LatLng((place['latitude'] as num).toDouble(), (place['longitude'] as num).toDouble()),
      mediaUrls: [for (final item in media) '$apiBase${(item as Map<String, dynamic>)['url']}'],
      authorId: json['author_id'] as String? ?? '',
      narratorRelation: json['narrator_relation'] as String?,
    );
  }
}

/// Un lugar que devuelve la búsqueda por nombre.
class PlaceHit {
  PlaceHit({required this.label, required this.latitude, required this.longitude, this.kind});

  final String label;
  final double latitude;
  final double longitude;

  /// Qué es según OpenStreetMap: city, town, village, province…
  final String? kind;

  static const _settlements = {'city', 'town', 'village', 'hamlet', 'suburb', 'quarter', 'neighbourhood', 'municipality'};

  bool get isSettlement => _settlements.contains(kind);

  /// Cómo se dice en castellano, o vacío si no hace falta aclararlo.
  String get kindLabel => switch (kind) {
    'city' => 'Ciudad',
    'town' || 'village' || 'municipality' => 'Pueblo',
    'hamlet' => 'Aldea',
    'suburb' || 'quarter' || 'neighbourhood' => 'Barrio',
    'province' => 'Provincia',
    'state' => 'Comunidad',
    'county' => 'Comarca',
    'country' => 'País',
    _ => '',
  };

  LatLng get point => LatLng(latitude, longitude);

  /// Nominatim da la dirección entera; la primera parte es el nombre del sitio.
  String get name => label.split(',').first.trim();

  /// El resto, recortado: municipio, provincia, país.
  String get context {
    final parts = label.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return '';
    return parts.skip(1).take(3).join(', ');
  }

  factory PlaceHit.fromJson(Map<String, dynamic> json) {
    return PlaceHit(
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      kind: json['kind'] as String?,
    );
  }
}

/// Nominatim devuelve a veces el mismo nombre dos veces (la provincia y la
/// ciudad de Soria). Se queda uno por nombre, mejor el que es un pueblo o una
/// ciudad, que es a donde quiere ir casi todo el mundo.
List<PlaceHit> distinctPlaces(List<PlaceHit> hits) {
  final byLabel = <String, PlaceHit>{};
  for (final hit in hits) {
    final current = byLabel[hit.label];
    if (current == null || (!current.isSettlement && hit.isSettlement)) byLabel[hit.label] = hit;
  }
  return byLabel.values.toList();
}

/// Una sola farola por lugar: si un sitio tiene varias historias, queda la primera.
List<StoryPin> onePinPerPlace(List<StoryPin> stories) {
  final seen = <String>{};
  return [
    for (final story in stories)
      if (seen.add(story.placeId)) story,
  ];
}

/// El backend solo acepta audio si el tipo viene declarado; sin esto el
/// fichero llega como application/octet-stream y lo rechaza.
MediaType audioType(String filename) {
  final extension = filename.split('.').last.toLowerCase();
  return switch (extension) {
    'mp3' => MediaType('audio', 'mpeg'),
    'm4a' || 'mp4' => MediaType('audio', 'mp4'),
    'aac' => MediaType('audio', 'aac'),
    'wav' => MediaType('audio', 'wav'),
    'webm' => MediaType('audio', 'webm'),
    'ogg' || 'opus' => MediaType('audio', 'ogg'),
    _ => MediaType('application', 'octet-stream'),
  };
}

class VocesApi {
  VocesApi({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  Account? account;

  /// Sube cada vez que algo cambia en el archivo (historia nueva, publicada,
  /// corregida, retirada) o en la sesión. Las páginas lo escuchan para recargar.
  final changes = ValueNotifier<int>(0);
  Timer? _pending;

  void _touched() {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 60), () => changes.value++);
  }

  bool owns(StoryPin story) => account != null && account!.id.isNotEmpty && story.authorId == account!.id;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    account = Account(
      token: token,
      id: prefs.getString('user_id') ?? '',
      displayName: prefs.getString('display_name') ?? '',
      role: prefs.getString('role') ?? 'contributor',
      email: prefs.getString('email') ?? '',
    );
    // El rol pudo cambiar y el token caducar: se comprueba sin bloquear el arranque.
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final current = account;
    if (current == null) return;
    try {
      final me = await _http.get(Uri.parse('$apiBase/api/v1/auth/me'), headers: _auth);
      if (me.statusCode == 401) {
        await logout();
        return;
      }
      if (me.statusCode != 200 || account != current) return;
      await _store(current.email, current.token, jsonDecode(me.body) as Map<String, dynamic>, expected: current);
      _touched();
    } catch (_) {
      // Sin conexión se sigue con lo guardado.
    }
  }

  Future<void> register(String email, String password, String displayName) async {
    final response = await _http.post(
      Uri.parse('$apiBase/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'display_name': displayName}),
    );
    _expect(response);
    await _keep(email, jsonDecode(response.body)['access_token'] as String);
  }

  Future<void> login(String email, String password) async {
    final response = await _http.post(
      Uri.parse('$apiBase/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _expect(response);
    await _keep(email, jsonDecode(response.body)['access_token'] as String);
  }

  Future<void> logout() async {
    account = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _touched();
  }

  Future<List<StoryPin>> mapStories(double west, double south, double east, double north, {int limit = 200}) async {
    final uri = Uri.parse('$apiBase/api/v1/stories/map').replace(
      queryParameters: {'west': '$west', 'south': '$south', 'east': '$east', 'north': '$north', 'limit': '$limit'},
    );
    final response = await _http.get(uri);
    _expect(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return [for (final row in rows) StoryPin.fromJson(row as Map<String, dynamic>)];
  }

  /// Todo lo publicado. El mapa del mundo entero cabe en un recuadro.
  Future<List<StoryPin>> archive() => mapStories(-180, -85, 180, 85, limit: 1000);

  Future<List<StoryPin>> mine() => _list('/api/v1/stories/mine', auth: true);

  /// Lo que espera revisión. Solo para quien modera.
  Future<List<StoryPin>> reviewQueue() => _list('/api/v1/stories/review', auth: true);

  Future<List<PlaceHit>> searchPlaces(String query) async {
    final uri = Uri.parse('$apiBase/api/v1/geocode').replace(queryParameters: {'q': query});
    final response = await _http.get(uri);
    _expect(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return distinctPlaces([for (final row in rows) PlaceHit.fromJson(row as Map<String, dynamic>)]);
  }

  /// La ficha tal como está ahora: con sesión se ven también las propias en revisión.
  Future<StoryPin> story(String id) async {
    final response = await _http.get(Uri.parse('$apiBase/api/v1/stories/$id'), headers: account == null ? null : _auth);
    _expect(response);
    return StoryPin.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<StoryPin>> _list(String path, {bool auth = false}) async {
    final response = await _http.get(Uri.parse('$apiBase$path'), headers: auth ? _auth : null);
    _expect(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return [for (final row in rows) StoryPin.fromJson(row as Map<String, dynamic>)];
  }

  Future<StoryPin> createStory({
    required String title,
    required String body,
    required String narratorName,
    required String relation,
    required bool deceased,
    required String license,
    required String placeName,
    required LatLng point,
    String category = 'anecdota',
  }) async {
    final response = await _http.post(
      Uri.parse('$apiBase/api/v1/stories'),
      headers: _jsonAuth,
      body: jsonEncode({
        'title': title,
        'body': body,
        'narrator_name': narratorName,
        'narrator_relation': relation.isEmpty ? null : relation,
        'narrator_consent': true,
        'narrator_deceased': deceased,
        'license': license,
        'category': category,
        'place': {'name': placeName, 'place_type': 'otro', 'latitude': point.latitude, 'longitude': point.longitude},
      }),
    );
    _expect(response);
    _touched();
    return StoryPin.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> uploadAudio(String storyId, String filename, List<int> bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiBase/api/v1/stories/$storyId/audio'));
    request.headers.addAll(_auth);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: audioType(filename)));
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    _expect(response);
    _touched();
  }

  Future<StoryPin> publish(String storyId) => _act(storyId, 'publish');

  Future<StoryPin> reject(String storyId) => _act(storyId, 'reject');

  /// Saca una historia del mapa y la devuelve a revisión.
  Future<StoryPin> unpublish(String storyId) => _act(storyId, 'unpublish');

  /// Quien la escribió la corrige mientras sigue en revisión.
  Future<StoryPin> updateStory(String storyId, {String? title, String? body, String? narratorName, String? narratorRelation}) async {
    final response = await _http.patch(
      Uri.parse('$apiBase/api/v1/stories/$storyId'),
      headers: _jsonAuth,
      body: jsonEncode({
        'title': ?title,
        'body': ?body,
        'narrator_name': ?narratorName,
        'narrator_relation': ?narratorRelation,
      }),
    );
    _expect(response);
    _touched();
    return StoryPin.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<StoryPin> _act(String storyId, String action) async {
    final response = await _http.post(Uri.parse('$apiBase/api/v1/stories/$storyId/$action'), headers: _auth);
    _expect(response);
    _touched();
    return StoryPin.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> get _auth {
    final current = account;
    if (current == null) throw ApiException('Entra en tu cuenta para hacer esto.');
    return {'Authorization': 'Bearer ${current.token}'};
  }

  Map<String, String> get _jsonAuth => {'Content-Type': 'application/json', ..._auth};

  Future<void> _keep(String email, String token) async {
    final me = await _http.get(Uri.parse('$apiBase/api/v1/auth/me'), headers: {'Authorization': 'Bearer $token'});
    _expect(me);
    await _store(email, token, jsonDecode(me.body) as Map<String, dynamic>);
    _touched();
  }

  /// Guarda la sesión. Con [expected], solo si sigue siendo la misma: si se
  /// cerró mientras tanto, no se resucita el token en disco.
  Future<void> _store(String email, String token, Map<String, dynamic> me, {Account? expected}) async {
    if (expected != null && account != expected) return;
    final next = Account(
      token: token,
      id: me['id'] as String? ?? '',
      displayName: me['display_name'] as String,
      role: me['role'] as String,
      email: email,
    );
    account = next;
    final prefs = await SharedPreferences.getInstance();
    final values = {'token': token, 'user_id': next.id, 'display_name': next.displayName, 'role': next.role, 'email': email};
    for (final entry in values.entries) {
      if (account != next) return;
      await prefs.setString(entry.key, entry.value);
    }
  }

  void _expect(http.Response response) {
    if (response.statusCode == 401 && account != null) {
      unawaited(logout());
      throw ApiException('La sesión ha caducado. Vuelve a entrar.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(_detail(response));
  }

  String _detail(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
    } catch (_) {}
    return 'La API respondió ${response.statusCode}';
  }
}

/// Da acceso a la API desde cualquier página, también las que se abren encima.
class ApiScope extends InheritedWidget {
  const ApiScope({super.key, required this.api, required super.child});

  final VocesApi api;

  static VocesApi of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ApiScope>()!.api;

  static VocesApi? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ApiScope>()?.api;

  @override
  bool updateShouldNotify(ApiScope old) => old.api != api;
}
