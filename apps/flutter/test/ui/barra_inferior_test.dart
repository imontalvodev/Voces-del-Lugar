import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/barra_inferior.dart';

import 'ayuda.dart';

Future<void> _barra(WidgetTester tester, {int activa = 1, ValueChanged<int>? onSeleccion, double abajo = 0}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(412, 915),
          padding: EdgeInsets.only(bottom: abajo),
        ),
        child: Scaffold(
          bottomNavigationBar: BarraInferior(seleccionada: activa, onSeleccion: onSeleccion ?? (_) {}),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cuatro secciones con icono y texto', (tester) async {
    await _barra(tester);
    for (final (texto, icono) in [
      ('Inicio', LucideIcons.house),
      ('Mapa', LucideIcons.map),
      ('Contar', LucideIcons.mic),
      ('Cuenta', LucideIcons.user),
    ]) {
      expect(find.text(texto), findsOneWidget);
      expect(find.byIcon(icono), findsOneWidget);
    }
  });

  testWidgets('68 px más la zona segura del sistema', (tester) async {
    await _barra(tester, abajo: 34);
    expect(tester.getSize(find.byType(BarraInferior)).height, 68 + 34);
  });

  testWidgets('la activa va en añil con la marca superior de 5 px', (tester) async {
    final semantica = tester.ensureSemantics();
    await _barra(tester, activa: 1);
    expect(tester.widget<Text>(find.text('Mapa')).style!.color, claro.anil);
    expect(tester.widget<Text>(find.text('Inicio')).style!.color, claro.piedra);
    final marca = find.byKey(const Key('marca-activa'));
    expect(marca, findsOneWidget);
    expect(tester.getSize(marca).height, 5);
    expect(tester.getCenter(marca).dx, closeTo(tester.getCenter(find.text('Mapa')).dx, 1));
    expect(tester.getTopLeft(marca).dy, tester.getTopLeft(find.byType(BarraInferior)).dy + 2);
    expect(tester.getSemantics(find.text('Mapa')), isSemantics(isSelected: true, isButton: true));
    semantica.dispose();
  });

  testWidgets('pulsar una sección avisa con su posición', (tester) async {
    int? elegida;
    await _barra(tester, onSeleccion: (i) => elegida = i);
    await tester.tap(find.text('Cuenta'));
    expect(elegida, 3);
  });

  testWidgets('con la letra muy grande no se desborda', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.4)),
          child: Scaffold(bottomNavigationBar: BarraInferior(seleccionada: 0, onSeleccion: (_) {})),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
