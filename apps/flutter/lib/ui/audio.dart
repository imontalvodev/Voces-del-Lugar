import 'dart:async';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:record/record.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/tokens.dart';

String clock(Duration value) {
  final minutes = value.inMinutes.toString();
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Reproductor de la grabación. La huella de voz sirve de barra: se toca o
/// se arrastra para ir a otro momento. Mientras suena, [energy] sube para
/// que el paisaje de la ficha hable con ella.
class StoryPlayer extends StatefulWidget {
  const StoryPlayer({super.key, required this.url, required this.seed, this.energy});

  final String url;
  final String seed;
  final ValueNotifier<double>? energy;

  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer> {
  final _player = AudioPlayer();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(
        _player.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        _player.durationStream.listen((d) {
          if (mounted && d != null) setState(() => _duration = d);
        }),
      )
      ..add(
        _player.playerStateStream.listen((state) {
          if (!mounted) return;
          final done = state.processingState == ProcessingState.completed;
          if (done) {
            _player.pause();
            _player.seek(Duration.zero);
          }
          setState(() {
            _playing = state.playing && !done;
            _loading = state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
          });
          widget.energy?.value = _playing ? 1.0 : 0.35;
        }),
      );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    widget.energy?.value = 0.35;
    super.dispose();
  }

  Future<bool> _prepare() async {
    if (_ready) return true;
    try {
      await _player.setUrl(widget.url);
      _ready = true;
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir la grabación. Comprueba la conexión y vuelve a tocar el botón.');
      return false;
    }
  }

  Future<void> _toggle() async {
    setState(() => _error = null);
    if (_playing) {
      await _player.pause();
      return;
    }
    if (await _prepare()) unawaited(_player.play());
  }

  Future<void> _seekTo(double fraction) async {
    if (!await _prepare() || _duration == Duration.zero) return;
    await _player.seek(_duration * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Glass(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
          child: Row(
            children: [
              _PlayButton(playing: _playing, loading: _loading, onTap: _toggle),
              const SizedBox(width: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    void seek(Offset local) => _seekTo(local.dx / constraints.maxWidth);
                    return Semantics(
                      slider: true,
                      label: 'Momento de la grabación',
                      value: '${clock(_position)} de ${clock(_duration)}',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => seek(d.localPosition),
                          onHorizontalDragUpdate: (d) => seek(d.localPosition),
                          child: VoicePrint(seed: widget.seed, bars: 56, progress: progress, alive: _playing, height: 52),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _duration == Duration.zero ? clock(_position) : '${clock(_position)} / ${clock(_duration)}',
                style: text(size: 13.5, color: Palette.haze, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: text(size: 13.5, color: Palette.alarm))],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.loading, required this.onTap});

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: playing ? 'Pausar la grabación' : 'Escuchar la grabación',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.settle),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: Palette.lampGlow,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Palette.lamp.withValues(alpha: playing ? 0.6 : 0.3),
              blurRadius: playing ? 34 : 18,
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(19),
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.deep),
              )
            : AnimatedSwitcher(
                duration: Motion.of(context, Motion.quick),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(playing ? LucideIcons.pause : LucideIcons.play, key: ValueKey(playing), color: Palette.deep, size: 26),
              ),
      ),
    );
  }
}

/// Lo que se ha grabado dentro de la app, listo para subir.
class RecordedClip {
  const RecordedClip({required this.bytes, required this.filename, required this.duration});

  final Uint8List bytes;
  final String filename;
  final Duration duration;
}

/// Grabadora: un botón grande que se enciende al hablar. Pensada para que
/// grabar a alguien mayor sea tocar una vez para empezar y otra para parar.
class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({super.key, required this.clip, required this.onChanged});

  final RecordedClip? clip;
  final ValueChanged<RecordedClip?> onChanged;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitude;
  Timer? _clock;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final _level = ValueNotifier<double>(0);
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amplitude?.cancel();
    _clock?.cancel();
    _pulse.dispose();
    _level.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'El navegador o el móvil no dejan usar el micrófono. Dale permiso en los ajustes y vuelve a intentarlo.');
        return;
      }
      final RecordConfig config;
      final String path;
      if (kIsWeb) {
        config = const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1);
        path = '';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1);
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voz-${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(config, path: path);
      _amplitude = _recorder.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
        _level.value = ((a.current + 48) / 48).clamp(0.0, 1.0);
      });
      _elapsed = Duration.zero;
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _pulse.repeat();
      setState(() => _recording = true);
      widget.onChanged(null);
    } catch (_) {
      setState(() => _error = 'No se pudo empezar a grabar. Prueba a adjuntar un archivo de audio.');
    }
  }

  Future<void> _stop() async {
    _clock?.cancel();
    await _amplitude?.cancel();
    _pulse.stop();
    _level.value = 0;
    setState(() {
      _recording = false;
      _saving = true;
    });
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('sin ruta');
      final bytes = await XFile(path).readAsBytes();
      widget.onChanged(RecordedClip(bytes: bytes, filename: kIsWeb ? 'grabacion.wav' : 'grabacion.m4a', duration: _elapsed));
    } catch (_) {
      if (mounted) setState(() => _error = 'La grabación no se pudo guardar. Vuelve a grabar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final label = _recording
        ? 'Grabando · toca para parar'
        : (clip != null ? 'Grabación lista · ${clock(clip.duration)}' : (_saving ? 'Guardando la grabación' : 'Toca para grabar'));
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, _level]),
            builder: (context, _) {
              return CustomPaint(
                painter: _RingsPainter(phase: _pulse.value, level: _level.value, active: _recording),
                child: Center(
                  child: Pressable(
                    onTap: _saving ? null : (_recording ? _stop : _start),
                    semanticLabel: _recording ? 'Parar la grabación' : 'Empezar a grabar',
                    child: AnimatedContainer(
                      duration: Motion.of(context, Motion.settle),
                      curve: Motion.emphasized,
                      width: 104 + _level.value * 14,
                      height: 104 + _level.value * 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _recording
                            ? const LinearGradient(
                                colors: [Palette.dusk, Palette.ember],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : Palette.lampGlow,
                        boxShadow: [BoxShadow(color: (_recording ? Palette.dusk : Palette.lamp).withValues(alpha: 0.45), blurRadius: 40)],
                      ),
                      child: Icon(_recording ? LucideIcons.square : LucideIcons.mic, size: 38, color: Palette.deep),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.quick),
          child: Text(
            _recording ? '${clock(_elapsed)}  ·  $label' : label,
            key: ValueKey(label + (_recording ? '$_elapsed' : '')),
            style: text(size: 15, weight: FontWeight.w600, color: _recording ? Palette.dusk : Palette.bone),
          ),
        ),
        if (clip != null && !_recording) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => widget.onChanged(null),
            icon: const Icon(LucideIcons.trash2, size: 18),
            label: const Text('Borrar y grabar otra vez'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: text(size: 13.5, color: Palette.alarm),
          ),
        ],
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.phase, required this.level, required this.active});

  final double phase;
  final double level;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.28;
    if (!active) {
      canvas.drawCircle(
        center,
        base * 1.45,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.lamp.withValues(alpha: 0.18),
      );
      return;
    }
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1.0;
      final radius = base + t * size.shortestSide * 0.22 * (0.6 + level);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + level * 2
          ..color = Palette.dusk.withValues(alpha: (1 - t) * 0.55),
      );
    }
    final spikes = Paint()
      ..color = Palette.lamp.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 48; i++) {
      final angle = i / 48 * math.pi * 2;
      final wobble = 0.5 + 0.5 * math.sin(angle * 5 + phase * math.pi * 6);
      final inner = base * 1.25;
      final outer = inner + 4 + level * 22 * wobble;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + dir * inner, center + dir * outer, spikes);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.phase != phase || old.level != level || old.active != active;
}
