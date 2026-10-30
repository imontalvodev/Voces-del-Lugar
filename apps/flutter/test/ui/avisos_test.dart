import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/placa.dart';

import 'ayuda.dart';

void main() {
  group('aviso', () {
    testWidgets('borde lateral de color, icono y título según el tono', (tester) async {
      await montar(
        tester,
        SizedBox(
          width: 400,
          child: Column(
            children: [
              for (final tono in TonoAviso.values)
                Aviso(key: Key(tono.name), tono: tono, titulo: 'Título ${tono.name}'),
            ],
          ),
        ),
      );
      for (final (tono, icono, color) in [
        (TonoAviso.info, LucideIcons.info, claro.anil),
        (TonoAviso.exito, LucideIcons.circleCheck, claro.verde),
        (TonoAviso.aviso, LucideIcons.triangleAlert, claro.ocreTinta),
        (TonoAviso.error, LucideIcons.circleAlert, claro.carmin),
      ]) {
        final aviso = find.byKey(Key(tono.name));
        final icon = tester.widget<Icon>(find.descendant(of: aviso, matching: find.byType(Icon)));
        expect(icon.icon, icono);
        expect(icon.color, color);
        final borde = decoracion(tester, aviso).border as Border;
        expect(borde.left, BorderSide(color: color, width: 8));
        expect(borde.top, BorderSide(color: claro.tinta, width: 1.5));
      }
    });

    testWidgets('dice qué hacer y puede llevar una acción', (tester) async {
      var reintentos = 0;
      await montar(
        tester,
        SizedBox(
          width: 400,
          child: Aviso(
            tono: TonoAviso.error,
            titulo: 'No hay conexión',
            texto: 'Revisa el wifi o los datos.',
            accion: BotonPlaca(
              etiqueta: 'Volver a intentarlo',
              variante: VarianteBoton.secundario,
              tamano: TamanoBoton.medio,
              onPressed: () => reintentos++,
            ),
          ),
        ),
      );
      expect(find.text('Revisa el wifi o los datos.'), findsOneWidget);
      await tester.tap(find.text('Volver a intentarlo'));
      expect(reintentos, 1);
    });
  });

  group('notificación breve', () {
    Future<BuildContext> base(WidgetTester tester) async {
      late BuildContext contexto;
      await montar(
        tester,
        Builder(
          builder: (context) {
            contexto = context;
            return const SizedBox();
          },
        ),
      );
      return contexto;
    }

    testWidgets('enseña el texto con su acción y se va a los 6 s', (tester) async {
      final context = await base(tester);
      var vista = 0;
      mostrarNotificacion(context, 'Publicada. Ya está en el mapa.', accion: 'Ver', onAccion: () => vista++);
      await tester.pumpAndSettle();
      expect(find.text('Publicada. Ya está en el mapa.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('notificacion'))).height, greaterThanOrEqualTo(60));
      final ver = tester.widget<Text>(find.text('Ver'));
      expect(ver.style!.decoration, TextDecoration.underline);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Publicada. Ya está en el mapa.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Publicada. Ya está en el mapa.'), findsNothing);
      expect(vista, 0);
    });

    testWidgets('la acción hace lo suyo y cierra la notificación', (tester) async {
      final context = await base(tester);
      var vista = 0;
      mostrarNotificacion(context, 'Publicada. Ya está en el mapa.', accion: 'Ver', onAccion: () => vista++);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(vista, 1);
      expect(find.text('Publicada. Ya está en el mapa.'), findsNothing);
    });

    testWidgets('un error lleva su icono', (tester) async {
      final context = await base(tester);
      mostrarNotificacion(context, 'No se ha podido guardar.', error: true);
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    });
  });

  group('diálogo de confirmación', () {
    Future<Future<bool>> abrir(WidgetTester tester, {bool oscuro = false, Size ventana = const Size(800, 1000)}) async {
      late BuildContext contexto;
      await montar(
        tester,
        Builder(
          builder: (context) {
            contexto = context;
            return const SizedBox();
          },
        ),
        oscuro: oscuro,
        ventana: ventana,
      );
      final respuesta = confirmar(
        contexto,
        titulo: '¿Publicar en el mapa?',
        mensaje: 'Cualquiera podrá ver y escuchar «Las verbenas de San Lorenzo».',
        si: 'Sí, publicar en el mapa',
      );
      await tester.pumpAndSettle();
      return respuesta;
    }

    testWidgets('pregunta, explica y ofrece las dos salidas', (tester) async {
      final respuesta = await abrir(tester);
      expect(find.text('¿Publicar en el mapa?'), findsOneWidget);
      expect(find.text('Cualquiera podrá ver y escuchar «Las verbenas de San Lorenzo».'), findsOneWidget);
      final si = tester.getRect(find.text('Sí, publicar en el mapa'));
      final no = tester.getRect(find.text('Cancelar'));
      expect(si.top, lessThan(no.top));
      await tester.tap(find.text('Sí, publicar en el mapa'));
      await tester.pumpAndSettle();
      expect(await respuesta, isTrue);
    });

    testWidgets('cancelar responde que no', (tester) async {
      final respuesta = await abrir(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await respuesta, isFalse);
    });

    testWidgets('va sobre un velo sólido y no pasa de 480 de ancho', (tester) async {
      await abrir(tester, oscuro: true, ventana: const Size(1440, 1000));
      final velo = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(velo.color, oscuro.scrim);
      expect(tester.getSize(find.byKey(const Key('dialogo'))).width, 480);
      final d = decoracion(tester, find.byKey(const Key('dialogo')));
      expect(d.boxShadow, [BoxShadow(color: oscuro.sombraBoton, offset: const Offset(6, 6))]);
      expect((d.border as Border).top, BorderSide(color: oscuro.tinta, width: 2));
    });
  });
}
