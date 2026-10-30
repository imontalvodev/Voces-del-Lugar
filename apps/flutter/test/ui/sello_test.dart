import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/ui/sello.dart';

import 'ayuda.dart';

void main() {
  group('chip de tipo', () {
    testWidgets('sin elegir lleva el icono del tipo y borde de tinta', (tester) async {
      await montar(tester, ChipTipo(categoria: 'leyenda', elegido: false, onPressed: () {}));
      expect(find.text('Leyenda'), findsOneWidget);
      expect(find.byIcon(LucideIcons.moon), findsOneWidget);
      final d = decoracion(tester, find.byType(ChipTipo));
      expect(d.color, claro.azulejo);
      expect((d.border as Border).top, BorderSide(color: claro.tinta, width: 2));
      expect(d.borderRadius, BorderRadius.circular(2));
      expect(tester.getSize(find.byType(ChipTipo)).height, 48);
    });

    testWidgets('el elegido va relleno de añil con una marca y se anuncia elegido', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, ChipTipo(categoria: 'anecdota', elegido: true, onPressed: () {}));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.byIcon(LucideIcons.messageCircle), findsNothing);
      expect(decoracion(tester, find.byType(ChipTipo)).color, claro.anil);
      expect(tester.widget<Text>(find.text('Anécdota')).style!.color, claro.sobreAnil);
      expect(tester.getSemantics(find.text('Anécdota')), isSemantics(isSelected: true, isButton: true));
      semantica.dispose();
    });

    testWidgets('«Todas» no lleva icono de tipo', (tester) async {
      var pulsado = false;
      await montar(tester, ChipTipo(categoria: null, elegido: false, onPressed: () => pulsado = true));
      expect(find.text('Todas'), findsOneWidget);
      await tester.tap(find.text('Todas'));
      expect(pulsado, isTrue);
    });

    test('cada tipo tiene su icono del diseño', () {
      expect(iconoTipo('anecdota'), LucideIcons.messageCircle);
      expect(iconoTipo('leyenda'), LucideIcons.moon);
      expect(iconoTipo('oficio'), LucideIcons.hammer);
      expect(iconoTipo('tradicion'), LucideIcons.bell);
      expect(iconoTipo('evento'), LucideIcons.calendarDays);
      expect(iconoTipo('otro'), LucideIcons.circle);
    });

    testWidgets('la etiqueta de tipo va a máquina con su icono', (tester) async {
      await montar(tester, const EtiquetaTipo('oficio'));
      expect(find.byIcon(LucideIcons.hammer), findsOneWidget);
      expect(tester.widget<Text>(find.text('Oficio')).style!.fontFamily, 'CourierPrime');
    });
  });

  group('sello', () {
    testWidgets('cada estado lleva icono, palabra en mayúsculas y su color', (tester) async {
      await montar(tester, Wrap(spacing: 16, runSpacing: 16, children: [for (final e in EstadoSello.values) Sello(e)]));
      for (final (estado, texto, icono, color) in [
        (EstadoSello.enRevision, 'EN REVISIÓN', LucideIcons.hourglass, claro.ocreTinta),
        (EstadoSello.publicada, 'PUBLICADA', LucideIcons.circleCheck, claro.verde),
        (EstadoSello.rechazada, 'RECHAZADA', LucideIcons.x, claro.carmin),
        (EstadoSello.retirada, 'RETIRADA', LucideIcons.eyeOff, claro.piedra),
        (EstadoSello.permisoFamilia, 'PERMISO DE LA FAMILIA', LucideIcons.check, claro.carmin),
        (EstadoSello.pendienteSubir, 'PENDIENTE DE SUBIR', LucideIcons.cloudUpload, claro.anil),
      ]) {
        final sello = find.byWidgetPredicate((w) => w is Sello && w.estado == estado);
        expect(
          find.descendant(of: sello, matching: find.text(texto)),
          findsOneWidget,
          reason: '$estado',
        );
        final icon = tester.widget<Icon>(find.descendant(of: sello, matching: find.byType(Icon)));
        expect(icon.icon, icono, reason: '$estado');
        expect(icon.color, color, reason: '$estado');
      }
    });

    testWidgets('en revisión y retirada llevan el borde discontinuo', (tester) async {
      await montar(tester, const Column(children: [Sello(EstadoSello.enRevision), Sello(EstadoSello.publicada)]));
      final bordes = tester.widgetList<CustomPaint>(find.byKey(const Key('sello-borde'))).toList();
      expect((bordes[0].painter as BordeSello).discontinuo, isTrue);
      expect((bordes[1].painter as BordeSello).discontinuo, isFalse);
    });

    testWidgets('va girado −3° sin animación', (tester) async {
      await montar(tester, const Sello(EstadoSello.publicada));
      final giro = tester.widget<Transform>(
        find.descendant(of: find.byType(Sello), matching: find.byType(Transform)).first,
      );
      final angulo = math.atan2(giro.transform.entry(1, 0), giro.transform.entry(0, 0));
      expect(angulo, closeTo(-3 * math.pi / 180, 0.0001));
    });

    testWidgets('el lector de pantalla lo oye en minúsculas', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const Sello(EstadoSello.enRevision));
      expect(find.bySemanticsLabel('Estado: En revisión'), findsOneWidget);
      semantica.dispose();
    });

    test('el estado de la API se traduce a su sello', () {
      expect(EstadoSello.deStatus('published'), EstadoSello.publicada);
      expect(EstadoSello.deStatus('pending_review'), EstadoSello.enRevision);
      expect(EstadoSello.deStatus('rejected'), EstadoSello.rechazada);
      expect(EstadoSello.deStatus('draft'), isNull);
    });
  });
}
