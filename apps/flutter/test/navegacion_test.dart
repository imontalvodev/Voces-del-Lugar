import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/barra_inferior.dart';

Future<void> _armazon(
  WidgetTester tester, {
  required Size ventana,
  Seccion inicial = Seccion.inicio,
  bool moderador = false,
}) async {
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var seccion = inicial;
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      home: StatefulBuilder(
        builder: (context, setState) => Armazon(
          seccion: seccion,
          moderador: moderador,
          onSeccion: (s) => setState(() => seccion = s),
          paginas: {for (final s in Seccion.values) s: Center(child: Text('Página ${s.name}'))},
        ),
      ),
    ),
  );
}

void main() {
  group('rutas', () {
    test('cada dirección lleva a su sección', () {
      expect(seccionDeRuta('/'), Seccion.inicio);
      expect(seccionDeRuta(null), Seccion.inicio);
      expect(seccionDeRuta('/mapa'), Seccion.mapa);
      expect(seccionDeRuta('/mapa?lugar=abc'), Seccion.mapa);
      expect(seccionDeRuta('/historia/abc'), Seccion.mapa);
      expect(seccionDeRuta('/contar/sitio'), Seccion.contar);
      expect(seccionDeRuta('/contar/permiso'), Seccion.contar);
      expect(seccionDeRuta('/cuenta'), Seccion.cuenta);
      expect(seccionDeRuta('/entrar'), Seccion.cuenta);
      expect(seccionDeRuta('/crear-cuenta'), Seccion.cuenta);
      expect(seccionDeRuta('/revisar'), Seccion.revisar);
      expect(seccionDeRuta('/revisar/abc'), Seccion.revisar);
      expect(seccionDeRuta('/otra-cosa'), Seccion.inicio);
    });
  });

  testWidgets('en el móvil hay barra inferior y cambia de sección', (tester) async {
    await _armazon(tester, ventana: const Size(412, 915));
    expect(find.byType(BarraInferior), findsOneWidget);
    expect(find.text('Página inicio'), findsOneWidget);
    await tester.tap(find.text('Mapa'));
    await tester.pump();
    expect(find.text('Página mapa'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('en «Contar» la barra inferior desaparece', (tester) async {
    await _armazon(tester, ventana: const Size(412, 915));
    await tester.tap(find.text('Contar'));
    await tester.pump();
    expect(find.text('Página contar'), findsOneWidget);
    expect(find.byType(BarraInferior), findsNothing);
  });

  testWidgets('en la tableta hay NavigationRail con «Por revisar» para quien modera', (tester) async {
    await _armazon(tester, ventana: const Size(800, 1000), moderador: true);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BarraInferior), findsNothing);
    expect(find.text('Por revisar'), findsOneWidget);
    await tester.tap(find.text('Por revisar'));
    await tester.pump();
    expect(find.text('Página revisar'), findsOneWidget);
  });

  testWidgets('sin moderar no aparece «Por revisar»', (tester) async {
    await _armazon(tester, ventana: const Size(800, 1000));
    expect(find.text('Por revisar'), findsNothing);
  });

  testWidgets('en el escritorio hay barra superior con «Contar una historia»', (tester) async {
    await _armazon(tester, ventana: const Size(1440, 1000));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BarraInferior), findsNothing);
    await tester.tap(find.text('Contar una historia'));
    await tester.pump();
    expect(find.text('Página contar'), findsOneWidget);
    await tester.tap(find.text('Cuenta'));
    await tester.pump();
    expect(find.text('Página cuenta'), findsOneWidget);
  });

  testWidgets('cada sección conserva su estado al volver a ella', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var seccion = Seccion.inicio;
    final pila = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        home: StatefulBuilder(
          builder: (context, setState) => Armazon(
            seccion: seccion,
            onSeccion: (s) => setState(() => seccion = s),
            paginas: {
              Seccion.inicio: PilaSeccion(navigatorKey: pila, raiz: const Text('Raíz de inicio')),
              Seccion.mapa: const Text('Página mapa'),
            },
          ),
        ),
      ),
    );
    pila.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('Ficha abierta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha abierta'), findsOneWidget);
  });
}
