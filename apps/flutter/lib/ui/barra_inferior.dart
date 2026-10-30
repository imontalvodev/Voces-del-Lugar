import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/placa.dart';

typedef Destino = ({String etiqueta, IconData icono});

/// Las cuatro secciones de la app, en el orden de la barra.
const destinosVdl = <Destino>[
  (etiqueta: 'Inicio', icono: LucideIcons.house),
  (etiqueta: 'Mapa', icono: LucideIcons.map),
  (etiqueta: 'Contar', icono: LucideIcons.mic),
  (etiqueta: 'Cuenta', icono: LucideIcons.user),
];

/// Barra inferior propia, igual en iPhone y Android: 68 px más la zona segura,
/// icono de 26, etiqueta de 15 y marca superior de 5 px en la activa.
class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.seleccionada, required this.onSeleccion, this.destinos = destinosVdl});

  final int seleccionada;
  final ValueChanged<int> onSeleccion;
  final List<Destino> destinos;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Secciones',
      child: Container(
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border(top: BorderSide(color: c.tinta, width: 2)),
        ),
        padding: EdgeInsets.only(bottom: abajo),
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (final (i, destino) in destinos.indexed)
                Expanded(
                  child: _Seccion(destino: destino, activa: i == seleccionada, onTap: () => onSeleccion(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.destino, required this.activa, required this.onTap});

  final Destino destino;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final color = activa ? c.anil : c.piedra;
    return PlacaPulsable(
      onPressed: onTap,
      hunde: false,
      seleccionado: activa,
      radio: 0,
      child: SizedBox.expand(
        child: Stack(
          children: [
            if (activa)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  widthFactor: 0.56,
                  child: Container(key: const Key('marca-activa'), height: 5, color: c.anil),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destino.icono, size: 26, color: color),
                  const SizedBox(height: 3),
                  Text(
                    destino.etiqueta,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 15,
                      height: 1.1,
                      color: color,
                      fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
