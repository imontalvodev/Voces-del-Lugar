import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/duraciones.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/campos.dart';
import 'package:voces/escuchar.dart';
import 'package:voces/ui/placa.dart';

String _tiempo(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Velocidades del botón: normal, más despacio y más deprisa.
const velocidades = [1.0, 0.75, 1.25];

String etiquetaVelocidad(double v) => '${v.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',')}×';

/// Reproductor de una grabación: botón de 64, barra con zona de toque de 48,
/// saltos de ±10 s y velocidad.
class Reproductor extends StatefulWidget {
  const Reproductor({super.key, required this.url, required this.titulo, this.narrador, this.empezar = false});

  final String url;
  final String titulo;

  /// Quién la cuenta, para la pantalla de bloqueo.
  final String? narrador;

  /// Empieza a sonar nada más abrirse (al llegar con «Escuchar»).
  final bool empezar;

  @override
  State<Reproductor> createState() => _ReproductorState();
}

class _ReproductorState extends State<Reproductor> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  Duration _posicion = Duration.zero;
  Duration _duracion = Duration.zero;
  bool _sonando = false;
  bool _terminado = false;
  bool _cargando = false;
  Future<bool>? _carga;
  double _velocidad = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.positionStream.listen((p) => mounted ? setState(() => _posicion = p) : null))
      ..add(
        _player.durationStream.listen((d) {
          if (!mounted || d == null) return;
          setState(() => _duracion = d);
          Duraciones.guardar(widget.url, d);
        }),
      )
      ..add(
        _player.playerStateStream.listen((state) {
          if (!mounted) return;
          final fin = state.processingState == ProcessingState.completed;
          if (fin) _player.pause();
          setState(() {
            _terminado = fin;
            _sonando = state.playing && !fin;
            _cargando =
                state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
          });
        }),
      );
    // Se abre ya para saber cuánto dura antes de darle a «Escuchar».
    if (widget.empezar) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _alternar());
    } else {
      _preparar(avisar: false);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    escucha?.desconectar(_player);
    _player.dispose();
    super.dispose();
  }

  Future<bool> _preparar({bool avisar = true}) async {
    final abierta = await (_carga ??= _abrir());
    if (!abierta) {
      _carga = null;
      if (avisar && mounted) {
        setState(() => _error = 'No se ha podido abrir la grabación. Revisa la conexión y vuelve a pulsar «Escuchar».');
      }
    }
    return abierta;
  }

  Future<bool> _abrir() async {
    try {
      await _player.setUrl(widget.url);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _alternar() async {
    setState(() => _error = null);
    if (_sonando) {
      await _player.pause();
      return;
    }
    if (!await _preparar()) return;
    if (_terminado) await _player.seek(Duration.zero);
    escucha?.conectar(_player, titulo: widget.titulo, narrador: widget.narrador);
    unawaited(_player.play());
  }

  Future<void> _ir(Duration a) async {
    if (!await _preparar()) return;
    final tope = _duracion == Duration.zero ? a : (a > _duracion ? _duracion : a);
    await _player.seek(tope < Duration.zero ? Duration.zero : tope);
  }

  Future<void> _cambiarVelocidad() async {
    final siguiente = velocidades[(velocidades.indexOf(_velocidad) + 1) % velocidades.length];
    setState(() => _velocidad = siguiente);
    await _player.setSpeed(siguiente);
  }

  @override
  Widget build(BuildContext context) {
    return ReproductorVista(
      titulo: widget.titulo,
      estado: _sonando
          ? EstadoReproductor.sonando
          : _terminado
          ? EstadoReproductor.terminado
          : (_posicion > Duration.zero ? EstadoReproductor.pausa : EstadoReproductor.sinEmpezar),
      cargando: _cargando,
      posicion: _posicion,
      duracion: _duracion,
      velocidad: _velocidad,
      error: _error,
      onAlternar: _alternar,
      onIr: _ir,
      onVelocidad: _cambiarVelocidad,
    );
  }
}

enum EstadoReproductor {
  sinEmpezar('Escuchar la historia'),
  sonando('Escuchando'),
  pausa('En pausa'),
  terminado('Terminado');

  const EstadoReproductor(this.texto);

  final String texto;
}

class ReproductorVista extends StatelessWidget {
  const ReproductorVista({
    super.key,
    required this.titulo,
    required this.estado,
    required this.posicion,
    required this.duracion,
    required this.velocidad,
    required this.onAlternar,
    required this.onIr,
    required this.onVelocidad,
    this.cargando = false,
    this.error,
  });

  final String titulo;
  final EstadoReproductor estado;
  final Duration posicion;
  final Duration duracion;
  final double velocidad;
  final bool cargando;
  final String? error;
  final VoidCallback onAlternar;
  final ValueChanged<Duration> onIr;
  final VoidCallback onVelocidad;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final sonando = estado == EstadoReproductor.sonando;
    final fraccion = duracion.inMilliseconds == 0
        ? 0.0
        : (posicion.inMilliseconds / duracion.inMilliseconds).clamp(0.0, 1.0);
    Widget salto(String etiqueta, IconData icono, int segundos) => BotonCuadrado(
      etiqueta: etiqueta,
      onPressed: () => onIr(posicion + Duration(seconds: segundos)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 20),
          Text(
            '10',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'AtkinsonHyperlegibleNext',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.tinta,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: 'Reproductor: $titulo',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.ficha,
          border: Border.all(color: c.tinta, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PlacaPulsable(
                  onPressed: onAlternar,
                  etiqueta: sonando ? 'Pausar' : 'Escuchar',
                  color: c.anil,
                  borde: c.anil,
                  sombra: BoxShadow(color: c.sombraBoton, offset: const Offset(2, 2)),
                  minimo: const Size(64, 64),
                  child: Icon(
                    cargando ? LucideIcons.hourglass : (sonando ? LucideIcons.pause : LucideIcons.play),
                    size: 30,
                    color: c.sobreAnil,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          estado.texto,
                          style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _Barra(
                        fraccion: fraccion,
                        valor: '${_tiempo(posicion)} de ${_tiempo(duracion)}',
                        onFraccion: duracion == Duration.zero ? null : (f) => onIr(duracion * f),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  '${_tiempo(posicion)} / ${duracion == Duration.zero ? '--:--' : _tiempo(duracion)}',
                  style: registro.copyWith(color: c.tinta),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    salto('Atrás 10 segundos', LucideIcons.rotateCcw, -10),
                    const SizedBox(width: 6),
                    salto('Adelante 10 segundos', LucideIcons.rotateCw, 10),
                    const SizedBox(width: 6),
                    BotonCuadrado(
                      etiqueta: 'Velocidad ${etiquetaVelocidad(velocidad)}',
                      lado: 48,
                      onPressed: onVelocidad,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 46),
                        child: Text(
                          etiquetaVelocidad(velocidad),
                          textAlign: TextAlign.center,
                          style: letra.bodySmall!.copyWith(fontWeight: FontWeight.w800, color: c.tinta),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (error != null) ...[const SizedBox(height: 10), MensajeError(error!)],
          ],
        ),
      ),
    );
  }
}

/// Barra de avance: 8 px de alto dentro de 48 de toque, con el tirador.
class _Barra extends StatelessWidget {
  const _Barra({required this.fraccion, required this.valor, required this.onFraccion});

  final double fraccion;
  final String valor;
  final ValueChanged<double>? onFraccion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        void ir(Offset local) => onFraccion?.call((local.dx / ancho).clamp(0.0, 1.0));
        return Semantics(
          slider: true,
          label: 'Posición en la grabación',
          value: valor,
          increasedValue: valor,
          decreasedValue: valor,
          onIncrease: onFraccion == null ? null : () => onFraccion!((fraccion + 0.05).clamp(0.0, 1.0)),
          onDecrease: onFraccion == null ? null : () => onFraccion!((fraccion - 0.05).clamp(0.0, 1.0)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => ir(d.localPosition),
            onHorizontalDragUpdate: (d) => ir(d.localPosition),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(color: c.filete, borderRadius: BorderRadius.circular(4)),
                  ),
                  Container(
                    width: ancho * fraccion,
                    height: 8,
                    decoration: BoxDecoration(color: c.anil, borderRadius: BorderRadius.circular(4)),
                  ),
                  Positioned(
                    left: ancho * fraccion - 11,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c.azulejo,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.anil, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
