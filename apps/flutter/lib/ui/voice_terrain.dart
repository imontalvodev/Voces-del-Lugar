import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:voces/ui/tokens.dart';

/// Una historia puesta sobre el relieve. [x] va de -1 (oeste) a 1 (este),
/// [z] de 0 (lejos, norte) a 1 (cerca, sur).
class TerrainBeacon {
  const TerrainBeacon({required this.id, required this.x, required this.z, required this.label});

  final String id;
  final double x;
  final double z;
  final String label;
}

/// Paisaje en 3D hecho de ondas de voz: cada fila es una línea de sonido
/// vista en perspectiva, y cada historia levanta un cerro con una farola.
/// Se proyecta a mano (cámara con guiñada y altura) y se pinta de atrás
/// hacia delante rellenando cada fila, así las cercanas tapan a las lejanas.
class VoiceTerrain extends StatefulWidget {
  const VoiceTerrain({
    super.key,
    this.beacons = const [],
    this.energy,
    this.onBeacon,
    this.selectedId,
    this.horizon = 0.42,
    this.rows = 34,
  });

  final List<TerrainBeacon> beacons;

  /// Cuánto "habla" el paisaje, de 0 a 1. Sin valor, respira despacio.
  final ValueListenable<double>? energy;
  final ValueChanged<String>? onBeacon;
  final String? selectedId;

  /// Altura del horizonte como fracción del alto disponible.
  final double horizon;
  final int rows;

  @override
  State<VoiceTerrain> createState() => _VoiceTerrainState();
}

class _VoiceTerrainState extends State<VoiceTerrain> with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _rise;
  final _frame = ValueNotifier<int>(0);
  double _time = 0;
  double _energy = 0.35;
  Offset _look = Offset.zero;
  Offset _lookTarget = Offset.zero;
  _BeaconField? _field;
  List<_Projected> _projected = const [];
  String? _hover;

  @override
  void initState() {
    super.initState();
    _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _ticker = createTicker((elapsed) {
      _time = elapsed.inMicroseconds / 1e6;
      final target = widget.energy?.value ?? 0.35;
      _energy += (target - _energy) * 0.08;
      _look = Offset.lerp(_look, _lookTarget, 0.05)!;
      _frame.value++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _ticker.stop();
      _rise.value = 1;
      _time = 12;
      _frame.value++;
    } else {
      if (!_ticker.isActive) _ticker.start();
      if (_rise.value == 0) _rise.forward();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceTerrain old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.beacons.map((b) => b.id).toList(), widget.beacons.map((b) => b.id).toList())) {
      _field = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rise.dispose();
    _frame.dispose();
    super.dispose();
  }

  _BeaconField _fieldFor(int rows) {
    return _field ??= _BeaconField.build(widget.beacons, rows, _Grid.columns);
  }

  String? _hit(Offset position) {
    _Projected? best;
    var bestDistance = 34.0;
    for (final p in _projected) {
      final distance = (p.orb - position).distance;
      if (distance < bestDistance) {
        best = p;
        bestDistance = distance;
      }
    }
    return best?.id;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        void look(Offset local) {
          _lookTarget = Offset((local.dx / size.width - 0.5) * 2, (local.dy / size.height - 0.5) * 2);
        }

        final interactive = widget.onBeacon != null && widget.beacons.isNotEmpty;
        Widget painted = RepaintBoundary(
          child: CustomPaint(
            size: size,
            isComplex: true,
            willChange: true,
            painter: _TerrainPainter(repaint: Listenable.merge([_frame, _rise]), state: this, rows: widget.rows, horizon: widget.horizon),
          ),
        );
        painted = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) {
            look(e.localPosition);
            if (!interactive) return;
            final hit = _hit(e.localPosition);
            if (hit != _hover) setState(() => _hover = hit);
          },
          onPointerMove: (e) => look(e.localPosition),
          child: painted,
        );
        if (!interactive) return painted;
        final hovered = _projected.where((p) => p.id == _hover).firstOrNull;
        return MouseRegion(
          cursor: _hover == null ? MouseCursor.defer : SystemMouseCursors.click,
          onExit: (_) {
            _lookTarget = Offset.zero;
            if (_hover != null) setState(() => _hover = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final id = _hit(details.localPosition);
              if (id != null) widget.onBeacon!(id);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                painted,
                if (hovered != null)
                  Positioned(
                    left: hovered.orb.dx + 14,
                    top: hovered.orb.dy - 40,
                    child: IgnorePointer(child: _BeaconLabel(label: hovered.label)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BeaconLabel extends StatelessWidget {
  const _BeaconLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.deep.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.lamp.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text(size: 13, weight: FontWeight.w600),
      ),
    );
  }
}

abstract final class _Grid {
  static const columns = 96;
  static const xSpan = 5.2;
  static const zFar = 7.5;
  static const zNear = 1.35;
}

/// Cerros precalculados de cada historia por celda; solo cambian con los datos.
class _BeaconField {
  _BeaconField(this.bumps, this.rowOf, this.colOf, this.beacons);

  final Float32List bumps;
  final List<int> rowOf;
  final List<int> colOf;
  final List<TerrainBeacon> beacons;

  static _BeaconField build(List<TerrainBeacon> beacons, int rows, int cols) {
    final bumps = Float32List(rows * cols);
    final rowOf = <int>[];
    final colOf = <int>[];
    for (final b in beacons) {
      final bx = b.x.clamp(-1.0, 1.0) * 2.1;
      final bz = _Grid.zFar + (_Grid.zNear + 1.6 - _Grid.zFar) * b.z.clamp(0.0, 1.0);
      var nearestRow = 0;
      var nearestCol = 0;
      var nearest = double.infinity;
      for (var r = 0; r < rows; r++) {
        final z = _zOf(r, rows);
        for (var c = 0; c < cols; c++) {
          final x = _xOf(c, cols);
          final dx = x - bx;
          final dz = z - bz;
          final d2 = dx * dx * 5.5 + dz * dz * 2.2;
          bumps[r * cols + c] += 0.62 * math.exp(-d2 * 2.4);
          if (d2 < nearest) {
            nearest = d2;
            nearestRow = r;
            nearestCol = c;
          }
        }
      }
      rowOf.add(nearestRow);
      colOf.add(nearestCol);
    }
    return _BeaconField(bumps, rowOf, colOf, beacons);
  }
}

double _zOf(int row, int rows) {
  final t = row / (rows - 1);
  return _Grid.zFar + (_Grid.zNear - _Grid.zFar) * t;
}

double _xOf(int col, int cols) => (col / (cols - 1) - 0.5) * 2 * _Grid.xSpan;

class _Projected {
  const _Projected(this.id, this.label, this.orb);

  final String id;
  final String label;
  final Offset orb;
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({required Listenable repaint, required this.state, required this.rows, required this.horizon}) : super(repaint: repaint);

  final _VoiceTerrainState state;
  final int rows;
  final double horizon;

  double _height(double x, double z, int row, int col, double t, double energy, Float32List bumps) {
    final u = x / 3.2;
    final envelope = math.exp(-u * u * 1.4);
    final swell = math.sin(x * 1.1 + z * 0.9 + t * 0.35) * math.sin(x * 0.55 - t * 0.21 + z * 1.7);
    final hills = 0.2 * (0.55 + 0.45 * swell);
    final carrier = math.sin(x * 7.5 - t * 2.4 + z * 3.1);
    final syllables = 0.5 + 0.5 * math.sin(t * 1.3 + z * 2.6 + math.sin(x * 0.8 + t * 0.4) * 2);
    final voice = 0.16 * energy * carrier * syllables;
    final hill = bumps[row * _Grid.columns + col];
    return envelope * (hills + voice) + hill * (0.85 + 0.15 * math.sin(t * 1.6 + row.toDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final rise = Motion.out.transform(state._rise.value);
    final t = state._time;
    final energy = state._energy;
    final look = state._look;
    final field = state._fieldFor(rows);
    final bumps = field.bumps;

    final yaw = look.dx * 0.16;
    final camY = 1.05 - look.dy * 0.12;
    final pivot = (_Grid.zFar + _Grid.zNear) / 2;
    final horizonY = size.height * horizon;
    final focal = (size.height - horizonY) * _Grid.zNear / camY * 1.08;
    final cx = size.width / 2;
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);

    Offset project(double x, double y, double z) {
      final dz = z - pivot;
      final rx = x * cosY - dz * sinY;
      final rz = x * sinY + dz * cosY + pivot;
      final depth = math.max(rz, 0.3);
      return Offset(cx + rx / depth * focal, horizonY + (camY - y) / depth * focal);
    }

    final land = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF231A38), Palette.deep],
      ).createShader(Rect.fromLTWH(0, horizonY - 40, size.width, size.height - horizonY + 40));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final projected = <_Projected>[];
    final beaconsByRow = <int, List<int>>{};
    for (var i = 0; i < field.beacons.length; i++) {
      beaconsByRow.putIfAbsent(field.rowOf[i], () => []).add(i);
    }

    final points = List<Offset>.filled(_Grid.columns, Offset.zero);
    for (var r = 0; r < rows; r++) {
      final depthT = r / (rows - 1);
      final z = _zOf(r, rows);
      final path = Path();
      for (var c = 0; c < _Grid.columns; c++) {
        final x = _xOf(c, _Grid.columns);
        final y = _height(x, z, r, c, t, energy, bumps) * rise;
        final p = project(x, y, z);
        points[c] = p;
        if (c == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      // El relleno llega a los bordes para que las filas lejanas, más
      // estrechas, no dejen escalones a los lados.
      final left = math.min(-8.0, points.first.dx);
      final right = math.max(size.width + 8, points.last.dx);
      final fill = Path()
        ..moveTo(left, points.first.dy)
        ..extendWithPath(path, Offset.zero)
        ..lineTo(right, points.last.dy)
        ..lineTo(right, size.height + 4)
        ..lineTo(left, size.height + 4)
        ..close();
      // Las filas lejanas son niebla: dejan pasar el cielo y el horizonte
      // se funde en vez de cortar como un muro.
      land.color = Color.fromRGBO(0, 0, 0, 0.18 + 0.82 * math.pow(depthT, 0.6));
      canvas.drawPath(fill, land);

      final near = Curves.easeIn.transform(depthT);
      stroke
        ..strokeWidth = 0.7 + near * 1.3
        ..shader = LinearGradient(
          colors: [
            Palette.plum.withValues(alpha: 0.0),
            Color.lerp(Palette.haze, Palette.dusk, near)!.withValues(alpha: 0.35 + near * 0.35),
            Color.lerp(Palette.dusk, Palette.lamp, near)!.withValues(alpha: 0.5 + near * 0.5),
            Color.lerp(Palette.haze, Palette.dusk, near)!.withValues(alpha: 0.35 + near * 0.35),
            Palette.plum.withValues(alpha: 0.0),
          ],
          stops: const [0.02, 0.28, 0.5, 0.72, 0.98],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));
      canvas.drawPath(path, stroke);

      for (final i in beaconsByRow[r] ?? const <int>[]) {
        final base = points[field.colOf[i]];
        final beacon = field.beacons[i];
        final selected = beacon.id == state.widget.selectedId || beacon.id == state._hover;
        final scale = (0.5 + depthT * 0.9) * rise;
        final orb = base.translate(0, -26 * scale);
        _drawLamp(canvas, base, orb, scale, t + i * 0.7, selected);
        projected.add(_Projected(beacon.id, beacon.label, orb));
      }
    }
    state._projected = projected;
  }

  void _drawLamp(Canvas canvas, Offset base, Offset orb, double scale, double t, bool selected) {
    if (scale <= 0.01) return;
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Palette.lamp.withValues(alpha: 0.0), Palette.lamp.withValues(alpha: 0.55)],
      ).createShader(Rect.fromPoints(base, orb))
      ..strokeWidth = 1.2 * scale;
    canvas.drawLine(base, orb, beam);
    final breathe = 0.85 + 0.15 * math.sin(t * 2.1);
    final halo = (selected ? 30.0 : 18.0) * scale * breathe;
    canvas.drawCircle(
      orb,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Palette.lamp.withValues(alpha: selected ? 0.55 : 0.35),
            Palette.ember.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: orb, radius: halo)),
    );
    canvas.drawCircle(orb, (selected ? 4.6 : 3.2) * scale + 0.6, Paint()..color = const Color(0xFFFFE7C2));
    if (selected) {
      final ring = (t * 0.8) % 1.0;
      canvas.drawCircle(
        orb,
        halo * (0.6 + ring * 1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Palette.lamp.withValues(alpha: (1 - ring) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter old) => old.rows != rows || old.horizon != horizon;
}

/// Reparte las historias sobre el relieve según sus coordenadas reales:
/// el oeste queda a la izquierda y el norte al fondo.
List<TerrainBeacon> beaconsFromPoints(List<({String id, double lat, double lon, String label})> items) {
  if (items.isEmpty) return const [];
  var minLat = double.infinity, maxLat = -double.infinity, minLon = double.infinity, maxLon = -double.infinity;
  for (final item in items) {
    minLat = math.min(minLat, item.lat);
    maxLat = math.max(maxLat, item.lat);
    minLon = math.min(minLon, item.lon);
    maxLon = math.max(maxLon, item.lon);
  }
  final lonSpan = math.max(maxLon - minLon, 1e-6);
  final latSpan = math.max(maxLat - minLat, 1e-6);
  final single = items.length == 1 || (lonSpan < 1e-5 && latSpan < 1e-5);
  return [
    for (final (index, item) in items.indexed)
      TerrainBeacon(
        id: item.id,
        label: item.label,
        x: single ? (index.isEven ? 0.0 : 0.3) : ((item.lon - minLon) / lonSpan - 0.5) * 1.7,
        z: single ? 0.55 : 0.1 + (1 - (item.lat - minLat) / latSpan) * 0.75,
      ),
  ];
}
