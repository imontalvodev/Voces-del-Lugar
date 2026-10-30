import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

/// Monta una pieza dentro del tema «Placa y registro».
Future<void> montar(
  WidgetTester tester,
  Widget pieza, {
  bool oscuro = false,
  double escala = 1,
  Size ventana = const Size(800, 1000),
}) async {
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      darkTheme: vdlTheme(VdlColors.oscuro, Brightness.dark),
      themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.topLeft, child: pieza),
        ),
      ),
    ),
  );
}

/// La decoración que pinta una pieza (la del primer DecoratedBox/Container bajo [finder]).
BoxDecoration decoracion(WidgetTester tester, Finder finder) {
  final box = tester.widgetList<DecoratedBox>(find.descendant(of: finder, matching: find.byType(DecoratedBox))).first;
  return box.decoration as BoxDecoration;
}

const claro = VdlColors.claro;
const oscuro = VdlColors.oscuro;
