import 'package:flutter/material.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';

/// «¿Cómo lees mejor?»: tres tamaños, cada uno con su muestra de texto.
class SelectorLetra extends StatelessWidget {
  const SelectorLetra({super.key, required this.preferencia});

  final PreferenciaLetra preferencia;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return ValueListenableBuilder<TamanoLetra>(
      valueListenable: preferencia,
      builder: (context, actual, _) {
        // La muestra enseña cada tamaño sin el ajuste propio ya aplicado,
        // pero sí con el del sistema.
        final sistema = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1) / actual.escala);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '¿Cómo lees mejor?',
                style: letra.bodyMedium!.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            for (final tamano in TamanoLetra.values) ...[
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: tamano == actual,
                label: tamano.nombre,
                excludeSemantics: true,
                onTap: () => preferencia.elegir(tamano),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => preferencia.elegir(tamano),
                  child: Container(
                    key: Key('letra-${tamano.name}'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: tamano == actual ? c.anilVelo : c.azulejo,
                      border: Border.all(color: tamano == actual ? c.anil : c.filete, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.azulejo,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.tinta, width: 2),
                          ),
                          child: tamano == actual
                              ? Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(color: c.anil, shape: BoxShape.circle),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(textScaler: sistema),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tamano.nombre,
                                  style: letra.bodyMedium!.copyWith(
                                    fontSize: 16 * tamano.escala,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Así se verá el texto.',
                                  style: letra.bodyMedium!.copyWith(
                                    fontSize: 16 * tamano.escala,
                                    height: 1.35,
                                    color: c.piedra,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
