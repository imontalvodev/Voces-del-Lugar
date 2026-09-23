import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/tokens.dart';

/// Superficie de cristal esmerilado sobre el cielo.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.tint = Palette.glass,
    this.blur = 22,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final double blur;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: shape,
            border: border ? Border.all(color: Palette.glassEdge) : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.0)],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Hunde un poco lo que se pulsa y lo levanta al pasar el ratón: respuesta
/// física a la mano, no decoración.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.semanticLabel, this.lift = true});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool lift;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;
  var _hover = false;
  var _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale = !enabled ? 1.0 : (_down ? 0.965 : (_hover && widget.lift ? 1.012 : 1.0));
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: enabled
              ? (_) {
                  setState(() => _down = false);
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: scale,
            duration: Motion.of(context, _down ? const Duration(milliseconds: 90) : Motion.settle),
            curve: _down ? Curves.easeOut : Curves.elasticOut,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: _focus ? Border.all(color: Palette.lamp, width: 2) : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Acción principal: una farola encendida.
class LampButton extends StatelessWidget {
  const LampButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Palette.deep))
        else if (icon != null)
          Icon(icon, size: 20, color: Palette.deep),
        if (busy || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: text(size: 16, weight: FontWeight.w700, color: Palette.deep, height: 1.1),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedOpacity(
        opacity: enabled || busy ? 1 : 0.45,
        duration: Motion.quick,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: Palette.lampGlow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Palette.lamp.withValues(alpha: enabled ? 0.38 : 0),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

/// Acción secundaria: contorno de cristal.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon, this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Glass(
          radius: 999,
          blur: 14,
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 44 : 54),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19, color: Palette.bone), const SizedBox(width: 9)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: text(size: compact ? 14.5 : 16, weight: FontWeight.w600, height: 1.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de icono sobre cristal.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 46});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        child: Glass(
          radius: size,
          blur: 16,
          tint: Palette.glassStrong.withValues(alpha: 0.55),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.44, color: Palette.bone),
          ),
        ),
      ),
    );
  }
}

/// Estado de una historia, con un punto de color que dice lo mismo que el texto.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'published' => Palette.sage,
      'rejected' => Palette.alarm,
      _ => Palette.lamp,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            storyStatusLabel(status),
            style: text(size: 12.5, color: color, weight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtro con relleno de farola cuando está elegido.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        lift: false,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.settle),
          curve: Motion.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Palette.lamp : Palette.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Palette.lamp : Palette.glassEdge),
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: text(size: 14, weight: FontWeight.w600, color: selected ? Palette.deep : Palette.bone, height: 1.1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Huella de voz: barras que salen del id de la historia, siempre las mismas
/// para la misma historia. Con [progress] se colorean las ya escuchadas;
/// con [alive] respiran como si alguien estuviera hablando.
class VoicePrint extends StatefulWidget {
  const VoicePrint({super.key, required this.seed, this.bars = 42, this.progress, this.alive = false, this.height = 44, this.dim = false});

  final String seed;
  final int bars;
  final double? progress;
  final bool alive;
  final double height;
  final bool dim;

  @override
  State<VoicePrint> createState() => _VoicePrintState();
}

class _VoicePrintState extends State<VoicePrint> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late List<double> _levels;

  @override
  void initState() {
    super.initState();
    _levels = voiceLevels(widget.seed, widget.bars);
    _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);
  }

  @override
  void didUpdateWidget(covariant VoicePrint old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed || old.bars != widget.bars) _levels = voiceLevels(widget.seed, widget.bars);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final run = widget.alive && !MediaQuery.disableAnimationsOf(context);
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _VoicePrintPainter(levels: _levels, progress: widget.progress, time: _time, alive: widget.alive, dim: widget.dim),
      ),
    );
  }
}

List<double> voiceLevels(String seed, int bars) {
  var hash = 2166136261;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
  }
  final random = math.Random(hash);
  var level = 0.4;
  return [
    for (var i = 0; i < bars; i++)
      () {
        level = (level * 0.55 + random.nextDouble() * 0.6).clamp(0.12, 1.0);
        final phrase = 0.55 + 0.45 * math.sin(i / bars * math.pi * (2 + hash % 3));
        return (level * phrase).clamp(0.1, 1.0);
      }(),
  ];
}

class _VoicePrintPainter extends CustomPainter {
  _VoicePrintPainter({required this.levels, required this.progress, required this.time, required this.alive, required this.dim})
    : super(repaint: time);

  final List<double> levels;
  final double? progress;
  final ValueNotifier<double> time;
  final bool alive;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final count = levels.length;
    final gap = size.width / count;
    final barWidth = math.max(1.5, gap * 0.5);
    final heard = progress == null ? -1 : (progress! * count);
    final t = time.value;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      var level = levels[i];
      if (alive) level = (level * (0.6 + 0.4 * math.sin(t * 7 + i * 0.9) * math.sin(t * 2.3 + i * 0.31)).abs()).clamp(0.08, 1.0);
      final h = math.max(barWidth, level * size.height);
      final x = gap * (i + 0.5);
      final played = progress != null && i < heard;
      final color = played
          ? Color.lerp(Palette.lamp, Palette.ember, i / count)!
          : (progress != null
                ? Palette.haze.withValues(alpha: 0.45)
                : Color.lerp(Palette.dusk, Palette.lamp, level)!.withValues(alpha: dim ? 0.5 : 0.9));
      paint
        ..color = color
        ..strokeWidth = barWidth;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoicePrintPainter old) =>
      old.progress != progress || old.levels != levels || old.alive != alive || old.dim != dim;
}

/// Hueco que espera datos: brilla de izquierda a derecha.
class LoadingSlab extends StatelessWidget {
  const LoadingSlab({super.key, this.height = 160, this.radius = 22});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      decoration: BoxDecoration(color: Palette.glass, borderRadius: BorderRadius.circular(radius)),
    );
    if (MediaQuery.disableAnimationsOf(context)) return box;
    return box.animate(onPlay: (c) => c.repeat()).shimmer(duration: 1600.ms, color: Palette.bone.withValues(alpha: 0.08));
  }
}

/// Aviso con la acción para salir de él.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.action, this.onAction, this.tone = Palette.alarm});

  final String message;
  final String? action;
  final VoidCallback? onAction;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: text(size: 14.5))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
