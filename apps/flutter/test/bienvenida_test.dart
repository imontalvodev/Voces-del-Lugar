import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/pages/bienvenida_page.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

Future<void> _montar(WidgetTester tester, PreferenciaLetra letra, VoidCallback onEmpezar) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: vdlTheme(VdlColors.claro, Brightness.light),
      builder: (context, child) => EscalaLetra(preferencia: letra, child: child!),
      home: BienvenidaPage(letra: letra, onEmpezar: onEmpezar),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pregunta cómo lees mejor con una muestra de cada tamaño', (tester) async {
    await _montar(tester, PreferenciaLetra(TamanoLetra.normal), () {});
    expect(find.text('Las historias de cada sitio, contadas por quien las vivió.'), findsOneWidget);
    expect(find.text('¿Cómo lees mejor?'), findsOneWidget);
    expect(find.text('Así se verá el texto.'), findsNWidgets(3));
    expect(find.text('Puedes cambiarlo cuando quieras en Cuenta.'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets('elegir un tamaño lo aplica y lo guarda', (tester) async {
    final letra = PreferenciaLetra(TamanoLetra.normal);
    await _montar(tester, letra, () {});
    await tester.ensureVisible(find.text('Muy grande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muy grande'));
    await tester.pumpAndSettle();
    expect(letra.value, TamanoLetra.muyGrande);
    expect((await PreferenciaLetra.cargar()).value, TamanoLetra.muyGrande);
    final muestra = tester.widget<Text>(find.text('Grande'));
    expect(muestra.style!.fontSize, closeTo(19.2, 0.01));
    expect(MediaQuery.textScalerOf(tester.element(find.text('Grande'))).scale(10), closeTo(10, 0.01));
  });

  testWidgets('«Empezar» la deja vista para no volver a salir', (tester) async {
    var empezado = false;
    expect(await bienvenidaVista(), isFalse);
    await _montar(tester, PreferenciaLetra(TamanoLetra.normal), () => empezado = true);
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(empezado, isTrue);
    expect(await bienvenidaVista(), isTrue);
  });
}
