import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/ui/placa.dart';

import 'ayuda.dart';

void main() {
  testWidgets('el botón grande mide 56 y el medio 48', (tester) async {
    await montar(
      tester,
      Column(
        children: [
          BotonPlaca(key: const Key('g'), etiqueta: 'Guardar la historia', onPressed: () {}),
          BotonPlaca(key: const Key('m'), etiqueta: 'Ver todas', tamano: TamanoBoton.medio, onPressed: () {}),
        ],
      ),
    );
    expect(tester.getSize(find.byKey(const Key('g'))).height, 56);
    expect(tester.getSize(find.byKey(const Key('m'))).height, 48);
  });

  testWidgets('el principal es añil con borde de 2, radio 4 y sombra sólida 2,2', (tester) async {
    await montar(tester, BotonPlaca(etiqueta: 'Guardar la historia', onPressed: () {}));
    final d = decoracion(tester, find.byType(BotonPlaca));
    expect(d.color, claro.anil);
    expect((d.border as Border).top, BorderSide(color: claro.anil, width: 2));
    expect(d.borderRadius, BorderRadius.circular(4));
    expect(d.boxShadow, [BoxShadow(color: claro.sombraBoton, offset: const Offset(2, 2))]);
    final texto = tester.widget<Text>(find.text('Guardar la historia'));
    expect(texto.style!.color, claro.sobreAnil);
    expect(texto.style!.fontWeight, FontWeight.w800);
  });

  testWidgets('secundario, peligro y peligro con borde llevan sus colores', (tester) async {
    await montar(
      tester,
      Column(
        children: [
          BotonPlaca(
            key: const Key('s'),
            etiqueta: 'Abrir el mapa',
            variante: VarianteBoton.secundario,
            onPressed: () {},
          ),
          BotonPlaca(key: const Key('p'), etiqueta: 'Sí, rechazar', variante: VarianteBoton.peligro, onPressed: () {}),
          BotonPlaca(
            key: const Key('b'),
            etiqueta: 'Retirar del mapa',
            variante: VarianteBoton.peligroBorde,
            onPressed: () {},
          ),
        ],
      ),
      oscuro: true,
    );
    final s = decoracion(tester, find.byKey(const Key('s')));
    expect(s.color, oscuro.azulejo);
    expect((s.border as Border).top.color, oscuro.anil);
    final p = decoracion(tester, find.byKey(const Key('p')));
    expect(p.color, oscuro.carmin);
    expect(tester.widget<Text>(find.text('Sí, rechazar')).style!.color, oscuro.sobreCarmin);
    final b = decoracion(tester, find.byKey(const Key('b')));
    expect(b.color, oscuro.azulejo);
    expect((b.border as Border).top.color, oscuro.carmin);
    expect(b.boxShadow, isEmpty);
  });

  testWidgets('al pulsar se hunde 2 px y pierde la sombra', (tester) async {
    var pulsado = 0;
    await montar(tester, BotonPlaca(etiqueta: 'Guardar la historia', onPressed: () => pulsado++));
    final antes = tester.getTopLeft(find.text('Guardar la historia'));
    final gesto = await tester.startGesture(tester.getCenter(find.byType(BotonPlaca)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Guardar la historia')) - antes, const Offset(2, 2));
    expect(decoracion(tester, find.byType(BotonPlaca)).boxShadow, isEmpty);
    await gesto.up();
    await tester.pumpAndSettle();
    expect(pulsado, 1);
    expect(tester.getTopLeft(find.text('Guardar la historia')), antes);
  });

  testWidgets('deshabilitado conserva el texto, pierde el color y no responde', (tester) async {
    await montar(tester, const BotonPlaca(etiqueta: 'Publicar en el mapa', onPressed: null));
    expect(find.text('Publicar en el mapa'), findsOneWidget);
    final d = decoracion(tester, find.byType(BotonPlaca));
    expect(d.color, claro.filete);
    expect(d.boxShadow, isEmpty);
    expect(tester.widget<Text>(find.text('Publicar en el mapa')).style!.color, claro.piedra);
    expect(
      tester.getSemantics(find.byType(BotonPlaca)),
      matchesSemantics(label: 'Publicar en el mapa', isButton: true, hasEnabledState: true, isFocusable: false),
    );
  });

  testWidgets('cargando enseña su texto con el reloj de arena y no se puede pulsar', (tester) async {
    var pulsado = 0;
    await montar(tester, BotonPlaca(etiqueta: 'Guardar', cargando: 'Guardando…', onPressed: () => pulsado++));
    expect(find.text('Guardando…'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    await tester.tap(find.byType(BotonPlaca));
    expect(pulsado, 0);
  });

  testWidgets('con la letra muy grande el texto cabe en varias líneas', (tester) async {
    await montar(
      tester,
      SizedBox(
        width: 200,
        child: BotonPlaca(etiqueta: 'Contar la historia de este sitio', expandir: true, onPressed: () {}),
      ),
      escala: 1.4,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BotonPlaca)).height, greaterThan(56));
  });

  testWidgets('el enlace discreto va subrayado en añil y tiene 48 de toque', (tester) async {
    var pulsado = 0;
    await montar(tester, EnlaceDiscreto(etiqueta: 'Ver todas', onPressed: () => pulsado++));
    final texto = tester.widget<Text>(find.text('Ver todas'));
    expect(texto.style!.color, claro.anil);
    expect(texto.style!.decoration, TextDecoration.underline);
    expect(tester.getSize(find.byType(EnlaceDiscreto)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Ver todas'));
    expect(pulsado, 1);
  });

  testWidgets('el botón cuadrado tiene 48 de toque, borde de tinta y su nombre', (tester) async {
    await montar(tester, BotonCuadrado(etiqueta: 'Cerrar', icono: Icons.close, onPressed: () {}));
    final size = tester.getSize(find.byType(BotonCuadrado));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, 48);
    expect(
      (decoracion(tester, find.byType(BotonCuadrado)).border as Border).top,
      BorderSide(color: claro.tinta, width: 2),
    );
    expect(find.bySemanticsLabel('Cerrar'), findsOneWidget);
  });

  testWidgets('con movimiento reducido el hundido es inmediato', (tester) async {
    await montar(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BotonPlaca(etiqueta: 'Guardar la historia', onPressed: () {}),
      ),
    );
    final antes = tester.getTopLeft(find.text('Guardar la historia'));
    final gesto = await tester.startGesture(tester.getCenter(find.byType(BotonPlaca)));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(find.text('Guardar la historia')) - antes, const Offset(2, 2));
    await gesto.up();
  });
}
