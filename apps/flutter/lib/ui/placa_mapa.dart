import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:voces/api.dart';
import 'package:voces/theme/vdl_colors.dart';

/// Un lugar del mapa con sus historias, en el orden en que llegaron.
class Lugar {
  Lugar({required this.id, required this.nombre, required this.punto, required this.historias});

  final String id;
  final String nombre;
  final LatLng punto;
  final List<StoryPin> historias;
}

/// Agrupa las historias por lugar: una placa por sitio, no por historia.
List<Lugar> lugaresDe(List<StoryPin> historias) {
  final porId = <String, Lugar>{};
  for (final h in historias) {
    porId
        .putIfAbsent(h.placeId, () => Lugar(id: h.placeId, nombre: h.placeName, punto: h.point, historias: []))
        .historias
        .add(h);
  }
  return porId.values.toList();
}

String recuentoHistorias(int n) => n == 1 ? '1 historia' : '$n historias';

/// Placa de azulejo que marca un lugar: nombre y recuento en un círculo ocre.
/// La elegida se ve invertida. Alto 36 más una cola de 13.
class PlacaLugar extends StatelessWidget {
  const PlacaLugar({
    super.key,
    required this.nombre,
    required this.recuento,
    required this.elegida,
    required this.onTap,
  });

  final String nombre;
  final int recuento;
  final bool elegida;
  final VoidCallback onTap;

  /// Tamaño que ocupa el marcador (la zona de toque llega a 48 de alto).
  static Size medida(String nombre, TextScaler escala) {
    final texto = TextPainter(
      text: TextSpan(
        text: nombre,
        style: const TextStyle(fontFamily: 'AtkinsonHyperlegibleNext', fontSize: 14, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
      textScaler: escala,
      maxLines: 1,
    )..layout();
    final ancho = texto.width + 11 + 8 + 22 + 6 + 12;
    final alto = math.max(texto.height, 22.0) + 16 + 13 + 8;
    texto.dispose();
    return Size(math.max(ancho, 60), math.max(alto, 52));
  }

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final tinta = elegida ? c.sobreAnil : c.anil;
    return Semantics(
      button: true,
      selected: elegida,
      label: '$nombre: ${recuentoHistorias(recuento)}${elegida ? ', seleccionado' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // La caja del marcador es una estimación: la placa puede asomar un
        // poco sin romper el dibujo.
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: elegida ? c.anil : c.azulejo,
                  border: Border.all(color: c.anil, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: c.sombraBoton, offset: const Offset(2, 2))],
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 3, 3, 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: tinta.withValues(alpha: 0.65)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'AtkinsonHyperlegibleNext',
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: tinta,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.ocre, shape: BoxShape.circle),
                        child: Text(
                          '$recuento',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'AtkinsonHyperlegibleNext',
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: c.sobreOcre,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              CustomPaint(size: const Size(16, 13), painter: _Cola(c.anil)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cola extends CustomPainter {
  _Cola(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Cola old) => old.color != color;
}

/// El sitio nuevo al tocar un sitio vacío: alfiler ocre con un círculo
/// discontinuo alrededor de la punta.
class PinNuevo extends StatelessWidget {
  const PinNuevo({super.key});

  static const medida = Size(48, 70);

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Semantics(
      label: 'Sitio elegido',
      child: CustomPaint(size: medida, painter: _Alfiler(c)),
    );
  }
}

class _Alfiler extends CustomPainter {
  _Alfiler(this.c);

  final VdlColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final punta = Offset(size.width / 2, size.height - 22);
    final circulo = Path()..addOval(Rect.fromCircle(center: punta, radius: 20));
    final trazo = Paint()
      ..color = c.ocre
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final PathMetric tramo in circulo.computeMetrics()) {
      for (var d = 0.0; d < tramo.length; d += 9) {
        canvas.drawPath(tramo.extractPath(d, math.min(d + 5, tramo.length)), trazo);
      }
    }
    final x = punta.dx;
    final y = punta.dy;
    final gota = Path()
      ..moveTo(x, y)
      ..cubicTo(x - 14, y - 18, x - 16, y - 24, x - 16, y - 32)
      ..arcToPoint(Offset(x + 16, y - 32), radius: const Radius.circular(16))
      ..cubicTo(x + 16, y - 24, x + 14, y - 18, x, y)
      ..close();
    canvas.drawPath(gota, Paint()..color = c.ocre);
    canvas.drawPath(
      gota,
      Paint()
        ..color = c.tinta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(Offset(x, y - 32), 6, Paint()..color = c.tinta);
  }

  @override
  bool shouldRepaint(_Alfiler old) => old.c != c;
}
