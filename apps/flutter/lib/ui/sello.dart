import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/placa.dart';

IconData iconoTipo(String categoria) {
  return switch (categoria) {
    'anecdota' => LucideIcons.messageCircle,
    'leyenda' => LucideIcons.moon,
    'oficio' => LucideIcons.hammer,
    'tradicion' => LucideIcons.bell,
    'evento' => LucideIcons.calendarDays,
    _ => LucideIcons.circle,
  };
}

/// Chip para elegir o filtrar el tipo de historia. Con [categoria] nula es «Todas».
class ChipTipo extends StatelessWidget {
  const ChipTipo({super.key, required this.categoria, required this.elegido, required this.onPressed});

  final String? categoria;
  final bool elegido;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final color = elegido ? c.sobreAnil : c.tinta;
    final icono = elegido ? LucideIcons.check : (categoria == null ? null : iconoTipo(categoria!));
    return PlacaPulsable(
      onPressed: onPressed,
      seleccionado: elegido,
      color: elegido ? c.anil : c.azulejo,
      borde: elegido ? c.anil : c.tinta,
      radio: 2,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 18, color: color), const SizedBox(width: 8)],
          Text(
            categoria == null ? 'Todas' : categoryLabel(categoria!),
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: color, height: 1.2, fontWeight: elegido ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Tipo de historia dentro de una ficha: icono y nombre, a máquina.
class EtiquetaTipo extends StatelessWidget {
  const EtiquetaTipo(this.categoria, {super.key, this.color});

  final String categoria;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tinta = color ?? DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconoTipo(categoria), size: 17, color: tinta),
        const SizedBox(width: 6),
        Text(categoryLabel(categoria), style: registro.copyWith(fontSize: 16, color: tinta)),
      ],
    );
  }
}

enum EstadoSello {
  enRevision('En revisión', LucideIcons.hourglass, discontinuo: true),
  publicada('Publicada', LucideIcons.circleCheck),
  rechazada('Rechazada', LucideIcons.x),
  retirada('Retirada', LucideIcons.eyeOff, discontinuo: true),
  permisoFamilia('Permiso de la familia', LucideIcons.check),
  pendienteSubir('Pendiente de subir', LucideIcons.cloudUpload, discontinuo: true);

  const EstadoSello(this.nombre, this.icono, {this.discontinuo = false});

  final String nombre;
  final IconData icono;
  final bool discontinuo;

  Color color(VdlColors c) {
    return switch (this) {
      enRevision => c.ocreTinta,
      publicada => c.verde,
      rechazada || permisoFamilia => c.carmin,
      retirada => c.piedra,
      pendienteSubir => c.anil,
    };
  }

  static EstadoSello? deStatus(String status) {
    return switch (status) {
      'published' => publicada,
      'pending_review' => enRevision,
      'rejected' => rechazada,
      _ => null,
    };
  }
}

/// Sello de estado: borde (discontinuo en revisión y retirada), icono y
/// palabra en mayúsculas. Girado −3°, quieto.
class Sello extends StatelessWidget {
  const Sello(this.estado, {super.key, this.grande = false, this.girado = true});

  final EstadoSello estado;
  final bool grande;
  final bool girado;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final color = estado.color(c);
    final sello = CustomPaint(
      key: const Key('sello-borde'),
      painter: BordeSello(color: color, discontinuo: estado.discontinuo),
      child: Container(
        color: c.azulejo,
        margin: const EdgeInsets.all(1),
        padding: grande
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(estado.icono, size: grande ? 18 : 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                estado.nombre.toUpperCase(),
                style: registro.copyWith(fontSize: grande ? 16 : 15, height: 1.15, letterSpacing: 0.3, color: color),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: 'Estado: ${estado.nombre}',
      excludeSemantics: true,
      child: girado ? Transform.rotate(angle: -3 * math.pi / 180, child: sello) : sello,
    );
  }
}

/// Borde de 2 px del sello, liso o discontinuo.
class BordeSello extends CustomPainter {
  BordeSello({required this.color, required this.discontinuo});

  final Color color;
  final bool discontinuo;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final caja = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(3));
    if (!discontinuo) {
      canvas.drawRRect(caja, pincel);
      return;
    }
    for (final PathMetric tramo in (Path()..addRRect(caja)).computeMetrics()) {
      for (var d = 0.0; d < tramo.length; d += 9) {
        canvas.drawPath(tramo.extractPath(d, math.min(d + 5, tramo.length)), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(BordeSello old) => old.color != color || old.discontinuo != discontinuo;
}
