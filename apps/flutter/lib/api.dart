import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8001');

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Account {
  Account({required this.token, required this.displayName, required this.role, required this.email});
  final String token;
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
      mediaUrls: [
        for (final item in media) '$apiBase${(item as Map<String, dynamic>)['url']}',
      ],
    );
  }
}

class VocesApi {
  Account? account;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    account = Account(
      token: token,
      displayName: prefs.getString('display_name') ?? '',
      role: prefs.getString('role') ?? 'contributor',
      email: prefs.getString('email') ?? '',
    );
  }

  Future<void> register(String email, String password, String displayName) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'display_name': displayName}),
    );
    _expect(response);
    await _keep(email, jsonDecode(response.body)['access_token'] as String);
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
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
  }

  Future<List<StoryPin>> mapStories(double west, double south, double east, double north) async {
    final uri = Uri.parse('$apiBase/api/v1/stories/map').replace(queryParameters: {
      'west': '$west',
      'south': '$south',
      'east': '$east',
      'north': '$north',
    });
    final response = await http.get(uri);
    _expect(response);
    final rows = jsonDecode(response.body) as List<dynamic>;
    return [for (final row in rows) StoryPin.fromJson(row as Map<String, dynamic>)];
  }

  Future<List<StoryPin>> archive() => mapStories(-9.5, 35.8, 4.5, 43.9);

  Future<List<StoryPin>> mine() async {
    final response = await http.get(
      Uri.parse('$apiBase/api/v1/stories/mine'),
      headers: {'Authorization': 'Bearer ${account!.token}'},
    );
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
  }) async {
    final response = await http.post(
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
        'category': 'anecdota',
        'place': {
          'name': placeName,
          'place_type': 'otro',
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      }),
    );
    _expect(response);
    return StoryPin.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> uploadAudio(String storyId, String filename, List<int> bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiBase/api/v1/stories/$storyId/audio'));
    request.headers['Authorization'] = 'Bearer ${account!.token}';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _expect(response);
  }

  Future<void> publish(String storyId) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/v1/stories/$storyId/publish'),
      headers: {'Authorization': 'Bearer ${account!.token}'},
    );
    _expect(response);
  }

  Map<String, String> get _jsonAuth => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${account!.token}',
      };

  Future<void> _keep(String email, String token) async {
    final me = await http.get(
      Uri.parse('$apiBase/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _expect(me);
    final body = jsonDecode(me.body) as Map<String, dynamic>;
    account = Account(
      token: token,
      displayName: body['display_name'] as String,
      role: body['role'] as String,
      email: email,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('display_name', account!.displayName);
    await prefs.setString('role', account!.role);
    await prefs.setString('email', email);
  }

  void _expect(http.Response response) {
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
