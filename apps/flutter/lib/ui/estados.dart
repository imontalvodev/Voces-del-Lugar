import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/sello.dart';

/// Carga: texto con reloj de arena y bloques fijos, sin brillo animado.
class Cargando extends StatelessWidget {
  const Cargando({super.key, this.texto = 'Cargando historias…', this.bloques = 3});

  final String texto;
  final int bloques;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    Widget barra(double ancho, double alto) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: ancho,
      child: Container(
        height: alto,
        decoration: BoxDecoration(color: c.filete, borderRadius: BorderRadius.circular(2)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(LucideIcons.hourglass, size: 20, color: c.piedra),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: c.piedra),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < bloques; i++)
          ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 10 : 18),
              child: CustomPaint(
                key: const Key('bloque-carga'),
                painter: BordeSello(color: c.filete, discontinuo: true, grosor: 1.5, radio: 2),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  padding: const EdgeInsets.all(16.5),
                  color: c.azulejo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      barra(0.7, 20),
                      const SizedBox(height: 12),
                      barra(0.45, 14),
                      const SizedBox(height: 8),
                      barra(0.55, 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Estado vacío: dice qué pasa y siempre ofrece algo que hacer.
class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.titulo, required this.accion, this.texto, this.icono});

  final String titulo;
  final String? texto;
  final IconData? icono;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return CustomPaint(
      painter: BordeSello(color: c.filete, discontinuo: true, radio: 2),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        color: c.azulejo,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) Icon(icono, size: 32, color: c.piedra),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: letra.bodyMedium!.copyWith(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
            ),
            if (texto != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    texto!,
                    textAlign: TextAlign.center,
                    style: letra.bodyMedium!.copyWith(fontSize: 17, color: c.piedra),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            accion,
          ],
        ),
      ),
    );
  }
}
