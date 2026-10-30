import 'package:flutter/material.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/placa.dart';

/// Pantalla propia antes de que el sistema pida un permiso: dice para qué es
/// y que la pregunta siguiente es del móvil. Devuelve `true` con «Continuar».
Future<bool> explicarPermiso(
  BuildContext context, {
  required IconData icono,
  required String titulo,
  required String texto,
}) async {
  final c = VdlColors.of(context);
  final respuesta = await showModalBottomSheet<bool>(
    context: context,
    barrierColor: c.scrim,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
    builder: (context) => _Explicacion(icono: icono, titulo: titulo, texto: texto),
  );
  return respuesta ?? false;
}

class _Explicacion extends StatelessWidget {
  const _Explicacion({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border(top: BorderSide(color: c.anil, width: 2)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.anil, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: c.anil)),
                    alignment: Alignment.center,
                    child: Icon(icono, size: 30, color: c.anil),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(header: true, child: Text(titulo, style: letra.titleLarge)),
              const SizedBox(height: 8),
              Text(texto, style: letra.bodyMedium!.copyWith(fontSize: 17, color: c.piedra)),
              const SizedBox(height: 18),
              BotonPlaca(etiqueta: 'Continuar', expandir: true, onPressed: () => Navigator.pop(context, true)),
              const SizedBox(height: 10),
              Center(child: EnlaceDiscreto(etiqueta: 'Ahora no', onPressed: () => Navigator.pop(context, false))),
            ],
          ),
        ),
      ),
    );
  }
}
