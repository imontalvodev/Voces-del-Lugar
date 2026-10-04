import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';

Map<String, dynamic> storyJson({String id = 's1', String placeId = 'p1', String status = 'pending_review', String author = 'u1'}) {
  return {
    'id': id,
    'title': 'La fuente',
    'body': 'Iban a por agua.',
    'narrator_name': 'Carmen',
    'narrator_relation': 'abuela',
    'license': 'CC-BY-SA-4.0',
    'status': status,
    'category': 'anecdota',
    'author_id': author,
    'place': {'id': placeId, 'name': 'Plaza', 'latitude': 40.41, 'longitude': -3.70},
    'media': [],
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PlaceHit separa el nombre del sitio del resto de la dirección', () {
    final hit = PlaceHit.fromJson({'label': 'Lavapiés, Centro, Madrid, Comunidad de Madrid, 28012, España', 'latitude': 40.4, 'longitude': -3.7});
    expect(hit.name, 'Lavapiés');
    expect(hit.context, 'Centro, Madrid, Comunidad de Madrid');
    expect(PlaceHit(label: 'Soria', latitude: 0, longitude: 0).context, '');
  });

  test('una sola farola por lugar aunque haya varias historias', () {
    final stories = [
      StoryPin.fromJson(storyJson(id: 'a', placeId: 'p1')),
      StoryPin.fromJson(storyJson(id: 'b', placeId: 'p1')),
      StoryPin.fromJson(storyJson(id: 'c', placeId: 'p2')),
    ];
    expect(onePinPerPlace(stories).map((s) => s.id), ['a', 'c']);
  });

  test('la ficha conoce a su autor y quien la escribió puede corregirla', () async {
    final requests = <http.Request>[];
    final api = VocesApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/login')) return http.Response(jsonEncode({'access_token': 't'}), 200);
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(jsonEncode({'id': 'u1', 'display_name': 'Ana', 'role': 'contributor', 'email': 'a@b.es'}), 200);
        }
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({...storyJson(), 'title': body['title']}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await api.login('a@b.es', 'una-clave-larga');
    final story = StoryPin.fromJson(storyJson());
    expect(api.owns(story), isTrue);
    expect(api.owns(StoryPin.fromJson(storyJson(author: 'otra'))), isFalse);

    final updated = await api.updateStory(story.id, title: 'La fuente vieja');
    expect(updated.title, 'La fuente vieja');
    final patch = requests.last;
    expect(patch.headers['Authorization'], 'Bearer t');
    expect(jsonDecode(patch.body), {'title': 'La fuente vieja'});
  });

  test('moderar llama a la ruta de cada acción y avisa del cambio', () async {
    final paths = <String>[];
    final api = VocesApi(
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        final status = switch (request.url.pathSegments.last) {
          'publish' => 'published',
          'reject' => 'rejected',
          _ => 'pending_review',
        };
        return http.Response(jsonEncode(storyJson(status: status)), 200);
      }),
    )..account = Account(token: 't', displayName: 'Mod', role: 'curator', email: 'm@b.es', id: 'm');
    var changes = 0;
    api.changes.addListener(() => changes++);

    expect((await api.publish('s1')).status, 'published');
    expect((await api.reject('s1')).status, 'rejected');
    expect((await api.unpublish('s1')).status, 'pending_review');
    expect(paths, ['POST /api/v1/stories/s1/publish', 'POST /api/v1/stories/s1/reject', 'POST /api/v1/stories/s1/unpublish']);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(changes, 1);
  });

  test('si la sesión caduca, se cierra y se dice por qué', () async {
    final api = VocesApi(client: MockClient((_) async => http.Response('{"detail":"Token no válido"}', 401)))
      ..account = Account(token: 'viejo', displayName: 'Ana', role: 'admin', email: 'a@b.es');
    await expectLater(api.mine(), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('caducado'))));
    await Future<void>.delayed(Duration.zero);
    expect(api.account, isNull);
  });

  test('la búsqueda de lugares pasa el texto y lee los resultados', () async {
    final api = VocesApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters['q'], 'Soria');
        return http.Response(jsonEncode([{'label': 'Soria, Castilla y León, España', 'latitude': 41.76, 'longitude': -2.46}]), 200);
      }),
    );
    final hits = await api.searchPlaces('Soria');
    expect(hits.single.point.latitude, 41.76);
  });
}
