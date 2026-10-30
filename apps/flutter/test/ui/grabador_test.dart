import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voces/ui/grabador.dart';

import 'ayuda.dart';

Future<List<String>> _vista(WidgetTester tester, EstadoGrabador estado, {String? motivo}) async {
  final pulsado = <String>[];
  await montar(
    tester,
    SizedBox(
      width: 380,
      child: GrabadorVista(
        estado: estado,
        segundos: 107,
        niveles: const [0.2, 0.8, 0.5],
        motivoPausa: motivo,
        onEmpezar: () => pulsado.add('empezar'),
        onPausar: () => pulsado.add('pausar'),
        onSeguir: () => pulsado.add('seguir'),
        onTerminar: () => pulsado.add('terminar'),
        onBorrar: () => pulsado.add('borrar'),
        onEscribir: () => pulsado.add('escribir'),
        onReintentar: () => pulsado.add('reintentar'),
      ),
    ),
  );
  return pulsado;
}

void main() {
  testWidgets('lista para grabar: botón carmín de 96 y lo que hay que hacer', (tester) async {
    final pulsado = await _vista(tester, EstadoGrabador.lista);
    expect(find.text('Lista para grabar'), findsOneWidget);
    expect(find.text('Pulsa para grabar'), findsOneWidget);
    expect(find.text('Habla cerca del móvil. Puedes pausar cuando quieras.'), findsOneWidget);
    final boton = find.bySemanticsLabel('Empezar a grabar');
    expect(tester.getSize(boton), const Size(96, 96));
    await tester.tap(boton);
    expect(pulsado, ['empezar']);
  });

  testWidgets('grabando: tiempo, «Pausar» y «Terminar»', (tester) async {
    final pulsado = await _vista(tester, EstadoGrabador.grabando);
    expect(find.text('Grabando'), findsOneWidget);
    expect(find.text('01:47'), findsOneWidget);
    await tester.tap(find.text('Pausar'));
    await tester.tap(find.text('Terminar'));
    expect(pulsado, ['pausar', 'terminar']);
  });

  testWidgets('en pausa por una llamada lo dice y ofrece seguir', (tester) async {
    final pulsado = await _vista(
      tester,
      EstadoGrabador.pausa,
      motivo: 'Se ha pausado por una llamada. Lo grabado está a salvo: pulsa «Seguir» cuando quieras.',
    );
    expect(find.text('En pausa'), findsOneWidget);
    expect(find.textContaining('Se ha pausado por una llamada'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    expect(pulsado, ['seguir']);
  });

  testWidgets('sin micrófono ofrece escribirla en su lugar', (tester) async {
    final pulsado = await _vista(tester, EstadoGrabador.sinMicrofono);
    expect(find.text('No podemos usar el micrófono'), findsOneWidget);
    await tester.tap(find.text('Escribirla en su lugar'));
    expect(pulsado, ['escribir']);
  });
}
