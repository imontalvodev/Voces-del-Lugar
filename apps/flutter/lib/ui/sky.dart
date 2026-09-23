import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:voces/ui/tokens.dart';

/// Fondo vivo de toda la app. Un shader pinta el crepúsculo; si el
/// dispositivo no lo compila, queda un degradado quieto con los mismos tonos.
class Sky extends StatefulWidget {
  const Sky({super.key, this.child});

  final Widget? child;

  @override
  State<Sky> createState() => _SkyState();
}

class _SkyState extends State<Sky> with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram?>? _program;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  Offset _pointer = const Offset(0.5, 0.35);
  Offset _target = const Offset(0.5, 0.35);
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program ??= ui.FragmentProgram.fromAsset('shaders/dusk.frag').then<ui.FragmentProgram?>((p) => p).catchError((_) => null);
    _program!.then((program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
    _ticker = createTicker((elapsed) {
      _pointer = Offset.lerp(_pointer, _target, 0.04)!;
      _time.value = elapsed.inMicroseconds / 1e6;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _target = Offset(e.localPosition.dx / size.width, e.localPosition.dy / size.height),
          onPointerMove: (e) => _target = Offset(e.localPosition.dx / size.width, e.localPosition.dy / size.height),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(size: size, painter: shader == null ? const _FallbackSky() : _ShaderSky(shader, _time, () => _pointer)),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _ShaderSky extends CustomPainter {
  _ShaderSky(this.shader, this.time, this.pointer) : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final Offset Function() pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pointer();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, p.dx)
      ..setFloat(4, p.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderSky old) => old.shader != shader;
}

class _FallbackSky extends CustomPainter {
  const _FallbackSky();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.deep, Palette.night, Palette.plum, Color(0xFF6E3B52)],
          stops: [0, 0.4, 0.8, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
