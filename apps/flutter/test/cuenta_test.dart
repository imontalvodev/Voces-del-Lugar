import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/avisos_push.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/revisar_page.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/ajustes_avisos.dart';

import 'apoyo/canal_falso.dart';

Map<String, dynamic> _h(String id, String status, {int numero = 12, String? motivo}) => {
  'id': id,
  'review_reason': motivo,
  'number': numero,
  'title': 'Historia $id',
  'body': 'Texto de $id',
  'narrator_name': 'Rosa Martín',
  'narrator_relation': 'madre',
  'license': 'CC-BY-SA-4.0',
  'status': status,
  'category': 'evento',
  'author_name': 'Elena Martín',
  'created_at': '2026-10-14T09:00:00Z',
  'place': {'id': 'p$id', 'name': 'Calle del Ave María', 'latitude': 40.4, 'longitude': -3.7},
  'media': [],
};

typedef _Responder = Future<http.Response> Function(http.Request request);

Future<(VocesApi, List<String>)> _montar(
  WidgetTester tester,
  Widget Function(VocesApi api) pagina, {
  String? rol,
  required _Responder responder,
  PreferenciaLetra? letra,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final llamadas = <String>[];
  final api = VocesApi(
    client: MockClient((r) {
      llamadas.add('${r.method} ${r.url.path}');
      return responder(r);
    }),
  );
  if (rol != null) {
    api.account = Account(token: 't', id: 'u1', displayName: 'Lucía Ortega', role: rol, email: 'lucia@correo.es');
  }
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        builder: (context, child) =>
            EscalaLetra(preferencia: letra ?? PreferenciaLetra(TamanoLetra.normal), child: child!),
        home: pagina(api),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api, llamadas);
}

Future<void> _pulsar(WidgetTester tester, String texto) async {
  final boton = find.text(texto).last;
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Widget _cuenta(VocesApi api) => AccountPage(api: api, onChanged: () {}, onLeaveStory: () {});

void main() {
  group('entrar', () {
    testWidgets('si no coinciden lo dice con las palabras del diseño', (tester) async {
      await _montar(
        tester,
        _cuenta,
        responder: (_) async => http.Response(jsonEncode({'detail': 'La contraseña no coincide'}), 401),
      );
      expect(find.text('Entrar'), findsWidgets);
      await tester.enterText(find.byType(TextField).at(0), 'lucia@correo.es');
      await tester.enterText(find.byType(TextField).at(1), 'otra-clave');
      await _pulsar(tester, 'Entrar');
      expect(find.text('El email o la contraseña no coinciden'), findsOneWidget);
      expect(find.text('Revísalos y vuelve a intentarlo.'), findsOneWidget);
    });

    testWidgets('al crear la cuenta, la contraseña corta dice cuántos caracteres faltan', (tester) async {
      await _montar(tester, _cuenta, responder: (_) async => http.Response('{}', 200));
      await _pulsar(tester, 'Crear una cuenta');
      expect(find.text('Alta'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Lucía Ortega');
      await tester.enterText(find.byType(TextField).at(1), 'lucia@correo.es');
      await tester.enterText(find.byType(TextField).at(2), 'abuel');
      await _pulsar(tester, 'Crear la cuenta');
      expect(find.text('Tiene 5 caracteres. Necesita al menos 8.'), findsOneWidget);
    });

    testWidgets('si la sesión caducó, lo dice al pedir entrar', (tester) async {
      await _montar(tester, (api) {
        api.sesionCaducada = true;
        return _cuenta(api);
      }, responder: (_) async => http.Response('{}', 200));
      expect(find.text('Tu sesión ha caducado'), findsOneWidget);
      expect(find.text('Entra otra vez. Lo que estabas haciendo sigue guardado.'), findsOneWidget);
    });
  });

  group('cuenta', () {
    testWidgets('rol, lo que has dejado con sus sellos y «Corregir» en revisión', (tester) async {
      await _montar(
        tester,
        _cuenta,
        rol: 'contributor',
        responder: (r) async => http.Response(
          jsonEncode([_h('a', 'pending_review'), _h('b', 'published', numero: 3), _h('c', 'rejected', numero: 4)]),
          200,
        ),
      );
      expect(find.text('Lucía Ortega'), findsOneWidget);
      expect(find.text('Colaboración'), findsOneWidget);
      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(find.text('PUBLICADA'), findsOneWidget);
      expect(find.text('RECHAZADA'), findsOneWidget);
      expect(find.text('Corregir'), findsOneWidget);
      expect(find.text('Ir a revisar'), findsNothing);
      expect(find.text('Salir de la cuenta'), findsOneWidget);
    });

    testWidgets('quien modera ve cuántas hay por revisar', (tester) async {
      await _montar(
        tester,
        _cuenta,
        rol: 'curator',
        responder: (r) async => http.Response(
          jsonEncode(r.url.path.endsWith('/review') ? [_h('x', 'pending_review'), _h('y', 'pending_review')] : []),
          200,
        ),
      );
      expect(find.textContaining('Por revisar: ', findRichText: true), findsOneWidget);
      expect(find.textContaining('2 historias', findRichText: true), findsOneWidget);
      expect(find.text('Ir a revisar'), findsOneWidget);
      expect(find.text('Todavía no has dejado ninguna historia'), findsOneWidget);
    });

    testWidgets('el tamaño de letra se cambia desde Ajustes', (tester) async {
      final letra = PreferenciaLetra(TamanoLetra.normal);
      await _montar(
        tester,
        _cuenta,
        rol: 'contributor',
        letra: letra,
        responder: (_) async => http.Response('[]', 200),
      );
      expect(find.text('Se suma al tamaño que tengas en el móvil.'), findsOneWidget);
      await _pulsar(tester, 'Muy grande');
      expect(letra.value, TamanoLetra.muyGrande);
    });
  });

  group('moderación', () {
    testWidgets('la cola va de la más antigua a la más nueva y se publica con confirmación', (tester) async {
      var cola = [_h('a', 'pending_review', numero: 188), _h('b', 'pending_review', numero: 191)];
      final (_, llamadas) = await _montar(
        tester,
        (api) => RevisarPage(api: api),
        rol: 'admin',
        responder: (r) async {
          if (r.url.path.endsWith('/publish')) {
            cola = cola.where((h) => !r.url.path.contains('/${h['id']}/')).toList();
            return http.Response(jsonEncode(_h('a', 'published', numero: 188)), 200);
          }
          return http.Response(jsonEncode(cola), 200);
        },
      );
      expect(find.text('Por revisar'), findsOneWidget);
      expect(find.text('De la más antigua a la más nueva.'), findsOneWidget);
      expect(find.text('1º · Nº 0188'), findsOneWidget);
      expect(find.text('2º · Nº 0191'), findsOneWidget);
      expect(find.text('14 oct 2026'), findsNWidgets(2));

      await _pulsar(tester, 'Historia a');
      expect(find.text('Volver a la cola'), findsOneWidget);
      expect(find.text('Subida por'), findsOneWidget);
      expect(find.text('Elena Martín'), findsOneWidget);
      expect(find.text('Confirmado por quien la subió'), findsOneWidget);

      await _pulsar(tester, 'Publicar en el mapa');
      expect(find.text('¿Publicar en el mapa?'), findsOneWidget);
      await _pulsar(tester, 'Sí, publicar en el mapa');
      expect(llamadas, contains('POST /api/v1/stories/a/publish'));
      expect(find.text('Publicada. Ya está en el mapa.'), findsOneWidget);
      expect(find.text('1º · Nº 0191'), findsOneWidget);
    });

    testWidgets('rechazar pide confirmación y lo dice exactamente', (tester) async {
      await _montar(
        tester,
        (api) => RevisarPage(api: api),
        rol: 'curator',
        responder: (r) async => http.Response(
          jsonEncode(r.url.path.endsWith('/reject') ? _h('a', 'rejected') : [_h('a', 'pending_review')]),
          200,
        ),
      );
      await _pulsar(tester, 'Historia a');
      await _pulsar(tester, 'Rechazar');
      expect(find.text('¿Rechazar esta historia?'), findsOneWidget);
      await _pulsar(tester, 'Sí, rechazar');
      expect(find.text('Rechazada. No llegará al mapa.'), findsOneWidget);
    });

    testWidgets('dice por qué el filtro la dejó esperando', (tester) async {
      await _montar(
        tester,
        (api) => RevisarPage(api: api),
        rol: 'admin',
        responder: (_) async => http.Response(jsonEncode([_h('a', 'pending_review', motivo: 'link'), _h('b', 'pending_review')]), 200),
      );
      expect(find.text('Lleva un enlace'), findsOneWidget);
      await _pulsar(tester, 'Historia a');
      expect(find.text('Por qué espera'), findsOneWidget);
      expect(find.text('Lleva un enlace'), findsOneWidget);
    });

    testWidgets('sin nada por revisar lo dice', (tester) async {
      await _montar(
        tester,
        (api) => RevisarPage(api: api),
        rol: 'admin',
        responder: (_) async => http.Response('[]', 200),
      );
      expect(find.text('No hay historias por revisar'), findsOneWidget);
    });

    testWidgets('quien no modera no entra', (tester) async {
      await _montar(
        tester,
        (api) => RevisarPage(api: api),
        rol: 'contributor',
        responder: (_) async => http.Response('[]', 200),
      );
      expect(find.text('Esta parte es solo para moderadores'), findsOneWidget);
    });
  });

  group('avisos', () {
    Future<http.Response> responder(http.Request r) async {
      final ruta = r.url.path;
      if (ruta.endsWith('/push/config')) return http.Response(jsonEncode({'vapid_public_key': null}), 200);
      if (ruta.endsWith('/push/prefs')) {
        final apagado = r.method == 'PATCH' && (jsonDecode(r.body) as Map)['notify_own'] == false;
        return http.Response(jsonEncode({'notify_own': !apagado, 'notify_review': true}), 200);
      }
      if (ruta.endsWith('/push/places') && r.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'id': 's1', 'name': 'Plaza Mayor', 'latitude': 41.8, 'longitude': -2.4, 'radius_m': 2000},
          ]),
          200,
        );
      }
      if (r.method == 'PUT' || r.method == 'DELETE') return http.Response('', 204);
      return http.Response('[]', 200);
    }

    Future<(VocesApi, List<String>, AvisosPush)> montarConAvisos(WidgetTester tester, String rol) async {
      final (api, llamadas) = await _montar(tester, _cuenta, rol: rol, responder: responder);
      final avisos = AvisosPush.instancia = AvisosPush(api: api, canal: CanalFalso());
      addTearDown(() => AvisosPush.instancia = null);
      api.changes.value++;
      await tester.pumpAndSettle();
      return (api, llamadas, avisos);
    }

    testWidgets('sin pedirlos, Cuenta ofrece recibirlos', (tester) async {
      final (_, llamadas, _) = await montarConAvisos(tester, 'contributor');
      expect(find.text('Recibir avisos en este móvil'), findsOneWidget);
      await _pulsar(tester, 'Recibir avisos en este móvil');
      expect(llamadas, contains('PUT /api/v1/push/devices'));
      expect(find.text('Cuando se publique o se rechace lo que dejo'), findsOneWidget);
    });

    testWidgets('con avisos se eligen cuáles y se quitan los sitios vigilados', (tester) async {
      final (_, llamadas, avisos) = await montarConAvisos(tester, 'contributor');
      await avisos.activar(elegir: (_) async => null);
      await tester.pumpAndSettle();
      expect(find.text('Cuando se publique o se rechace lo que dejo'), findsOneWidget);
      expect(find.text('Cuando haya historias por revisar'), findsNothing);
      expect(find.text('Plaza Mayor'), findsOneWidget);
      expect(find.text('2 km a la redonda'), findsOneWidget);

      await _pulsar(tester, 'Cuando se publique o se rechace lo que dejo');
      expect(llamadas, contains('PATCH /api/v1/push/prefs'));

      await tester.tap(find.bySemanticsLabel('Dejar de vigilar Plaza Mayor'));
      await tester.pumpAndSettle();
      expect(llamadas, contains('DELETE /api/v1/push/places/s1'));
      expect(find.text('Plaza Mayor'), findsNothing);
      expect(find.text('Ya no te avisaremos de Plaza Mayor.'), findsOneWidget);
    });

    testWidgets('quien modera elige también si le avisan de lo que hay por revisar', (tester) async {
      final (_, _, avisos) = await montarConAvisos(tester, 'curator');
      await avisos.activar(elegir: (_) async => null);
      await tester.pumpAndSettle();
      expect(find.text('Cuando haya historias por revisar'), findsOneWidget);
    });

    testWidgets('dejar de recibirlos pide confirmación', (tester) async {
      final (_, llamadas, avisos) = await montarConAvisos(tester, 'contributor');
      await avisos.activar(elegir: (_) async => null);
      await tester.pumpAndSettle();
      await _pulsar(tester, 'Dejar de recibir avisos');
      expect(find.text('¿Dejar de recibir avisos?'), findsOneWidget);
      await _pulsar(tester, 'Sí, dejar de recibirlos');
      expect(llamadas, contains('DELETE /api/v1/push/devices'));
      expect(find.text('Recibir avisos en este móvil'), findsOneWidget);
    });

    test('el radio se lee en metros o kilómetros', () {
      expect(radioLegible(2000), '2 km');
      expect(radioLegible(1500), '1,5 km');
      expect(radioLegible(500), '500 m');
    });
  });
}
