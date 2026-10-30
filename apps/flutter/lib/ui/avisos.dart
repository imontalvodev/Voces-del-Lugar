import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/placa.dart';

enum TonoAviso {
  info(LucideIcons.info),
  exito(LucideIcons.circleCheck),
  aviso(LucideIcons.triangleAlert),
  error(LucideIcons.circleAlert);

  const TonoAviso(this.icono);

  final IconData icono;

  Color color(VdlColors c) {
    return switch (this) {
      info => c.anil,
      exito => c.verde,
      aviso => c.ocreTinta,
      error => c.carmin,
    };
  }
}

/// Aviso con borde lateral de color, icono y título. El texto dice qué hacer.
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.tono, required this.titulo, this.texto, this.accion});

  final TonoAviso tono;
  final String titulo;
  final String? texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final color = tono.color(c);
    final letra = Theme.of(context).textTheme;
    final filete = BorderSide(color: c.tinta, width: 1.5);
    return Semantics(
      container: true,
      liveRegion: tono == TonoAviso.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border(
            top: filete,
            right: filete,
            bottom: filete,
            left: BorderSide(color: color, width: 8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(tono.icono, size: 24, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800, height: 1.35),
                  ),
                  if (texto != null) ...[const SizedBox(height: 4), Text(texto!, style: letra.bodySmall)],
                  if (accion != null) ...[const SizedBox(height: 10), accion!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notificación breve: 6 s, con una acción opcional subrayada.
void mostrarNotificacion(
  BuildContext context,
  String texto, {
  String? accion,
  VoidCallback? onAccion,
  bool error = false,
}) {
  final mensajero = ScaffoldMessenger.of(context);
  mensajero.hideCurrentSnackBar();
  mensajero.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _Notificacion(
        texto: texto,
        error: error,
        accion: accion,
        onAccion: onAccion == null
            ? null
            : () {
                mensajero.hideCurrentSnackBar();
                onAccion();
              },
      ),
    ),
  );
}

class _Notificacion extends StatelessWidget {
  const _Notificacion({required this.texto, required this.error, this.accion, this.onAccion});

  final String texto;
  final bool error;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Container(
      key: const Key('notificacion'),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      decoration: BoxDecoration(
        color: c.tinta,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: c.sombraBoton, offset: const Offset(3, 3))],
      ),
      child: Row(
        children: [
          Icon(error ? LucideIcons.circleAlert : LucideIcons.circleCheck, size: 22, color: c.cal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: c.cal, height: 1.35),
            ),
          ),
          if (accion != null)
            PlacaPulsable(
              onPressed: onAccion,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                accion!,
                style: letra.bodySmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.cal,
                  decoration: TextDecoration.underline,
                  decorationColor: c.cal,
                  decorationThickness: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Diálogo de confirmación sobre un velo sólido. Devuelve `true` solo si se
/// pulsa [si]; cerrarlo de cualquier otra forma es que no.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String si,
  String? mensaje,
  String no = 'Cancelar',
  bool peligro = false,
  Widget? contenido,
}) async {
  final c = VdlColors.of(context);
  final quieto = MediaQuery.disableAnimationsOf(context);
  final respuesta = await showDialog<bool>(
    context: context,
    barrierColor: c.scrim,
    animationStyle: quieto ? AnimationStyle.noAnimation : null,
    builder: (context) => DialogoVdl(
      titulo: titulo,
      acciones: [
        BotonPlaca(
          etiqueta: si,
          expandir: true,
          variante: peligro ? VarianteBoton.peligro : VarianteBoton.principal,
          onPressed: () => Navigator.pop(context, true),
        ),
        BotonPlaca(
          etiqueta: no,
          expandir: true,
          variante: VarianteBoton.secundario,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mensaje != null) Text(mensaje, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 17)),
          ?contenido,
        ],
      ),
    ),
  );
  return respuesta ?? false;
}

/// Caja de diálogo del diseño: ancho máximo 480, borde 2, sombra sólida 6,6.
class DialogoVdl extends StatelessWidget {
  const DialogoVdl({super.key, required this.titulo, required this.child, this.acciones = const []});

  final String titulo;
  final Widget child;

  /// De arriba abajo: la principal primero.
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          key: const Key('dialogo'),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: c.azulejo,
            border: Border.all(color: c.tinta, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: c.sombraBoton, offset: const Offset(6, 6))],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: Text(titulo, style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 10),
                child,
                if (acciones.isNotEmpty) const SizedBox(height: 20),
                for (final (i, accion) in acciones.indexed) ...[if (i > 0) const SizedBox(height: 10), accion],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
