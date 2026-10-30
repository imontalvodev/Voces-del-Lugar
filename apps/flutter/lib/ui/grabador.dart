import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:voces/grabacion_fondo.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/reproductor.dart';

/// Lo grabado dentro de la app, listo para subir.
class Grabacion {
  const Grabacion({required this.bytes, required this.nombre, required this.duracion, this.ruta});

  final Uint8List bytes;
  final String nombre;
  final Duration duracion;

  /// En el móvil, el fichero en disco (sirve para escucharla y para el borrador).
  final String? ruta;

  String get url => ruta != null
      ? Uri.file(ruta!).toString()
      : Uri.dataFromBytes(bytes, mimeType: nombre.endsWith('.wav') ? 'audio/wav' : 'audio/mp4').toString();
}

enum EstadoGrabador { lista, grabando, pausa, terminada, sinMicrofono }

/// Grabador: botón carmín de 96, tiempo y medidor de voz. El medidor se
/// repinta solo cuando llega un nivel nuevo del micrófono.
class Grabador extends StatefulWidget {
  const Grabador({
    super.key,
    required this.grabacion,
    required this.onCambio,
    required this.onEscribir,
    this.antesDePedir,
    this.abrirAjustes,
  });

  final Grabacion? grabacion;
  final ValueChanged<Grabacion?> onCambio;

  /// «Escribirla en su lugar», si no hay micrófono.
  final VoidCallback onEscribir;

  /// Pantalla propia antes de que el móvil pida el micrófono; `false` cancela.
  final Future<bool> Function()? antesDePedir;
  final Future<void> Function()? abrirAjustes;

  @override
  State<Grabador> createState() => GrabadorState();
}

class GrabadorState extends State<Grabador> {
  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _nivel;
  Timer? _reloj;
  final _niveles = <double>[];
  int _segundos = 0;
  late EstadoGrabador _estado = widget.grabacion == null ? EstadoGrabador.lista : EstadoGrabador.terminada;
  bool _guardando = false;
  String? _error;
  String? _motivoPausa;
  StreamSubscription<AudioInterruptionEvent>? _interrupciones;
  final _aviso = AvisoGrabacion.instancia;

  @override
  void initState() {
    super.initState();
    _aviso.accion.addListener(_desdeNotificacion);
    _escucharInterrupciones();
  }

  /// Si entra una llamada, se pausa sola y lo dice: lo grabado queda a salvo.
  Future<void> _escucharInterrupciones() async {
    if (kIsWeb) return;
    try {
      final sesion = await AudioSession.instance;
      _interrupciones = sesion.interruptionEventStream.listen((evento) {
        if (evento.begin && _estado == EstadoGrabador.grabando) {
          _pausar(motivo: 'Se ha pausado por una llamada. Lo grabado está a salvo: pulsa «Seguir» cuando quieras.');
        }
      });
    } catch (_) {}
  }

  /// Pausar, Seguir o Terminar desde la notificación fija.
  void _desdeNotificacion() {
    switch (_aviso.accion.value) {
      case 'pausar' when _estado == EstadoGrabador.grabando:
        _pausar();
      case 'seguir' when _estado == EstadoGrabador.pausa:
        _seguir();
      case 'terminar' when _estado == EstadoGrabador.grabando || _estado == EstadoGrabador.pausa:
        _terminar();
    }
  }

  @override
  void dispose() {
    _aviso.accion.removeListener(_desdeNotificacion);
    _interrupciones?.cancel();
    _nivel?.cancel();
    _reloj?.cancel();
    if (_estado == EstadoGrabador.grabando || _estado == EstadoGrabador.pausa) _aviso.quitar();
    _recorder.dispose();
    super.dispose();
  }

  void _contar() {
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _segundos++);
    });
  }

  Future<void> _empezar() async {
    setState(() => _error = null);
    if (widget.antesDePedir != null && !await widget.antesDePedir!()) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _estado = EstadoGrabador.sinMicrofono);
        return;
      }
      final RecordConfig config;
      final String ruta;
      if (kIsWeb) {
        config = const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1);
        ruta = '';
      } else {
        // m4a/AAC, 64 kbps, mono: medio mega por minuto.
        config = const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1);
        final dir = await getApplicationDocumentsDirectory();
        ruta = '${dir.path}/voz-${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(config, path: ruta);
      _nivel = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
        if (!mounted || _estado != EstadoGrabador.grabando) return;
        setState(() {
          _niveles.add(((a.current + 48) / 48).clamp(0.0, 1.0));
          if (_niveles.length > 28) _niveles.removeAt(0);
        });
      });
      HapticFeedback.mediumImpact();
      _segundos = 0;
      _niveles.clear();
      _contar();
      unawaited(_aviso.mostrar(llevado: Duration.zero, pausada: false));
      if (mounted) setState(() => _estado = EstadoGrabador.grabando);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se ha podido empezar a grabar. Prueba a escribirla o a subir un audio.');
    }
  }

  Future<void> _pausar({String? motivo}) async {
    _reloj?.cancel();
    await _recorder.pause();
    unawaited(_aviso.mostrar(llevado: Duration(seconds: _segundos), pausada: true));
    if (mounted) {
      setState(() {
        _estado = EstadoGrabador.pausa;
        _motivoPausa = motivo;
      });
    }
  }

  Future<void> _seguir() async {
    await _recorder.resume();
    _contar();
    unawaited(_aviso.mostrar(llevado: Duration(seconds: _segundos), pausada: false));
    if (mounted) {
      setState(() {
        _estado = EstadoGrabador.grabando;
        _motivoPausa = null;
      });
    }
  }

  Future<void> _terminar() async {
    _reloj?.cancel();
    await _nivel?.cancel();
    unawaited(_aviso.quitar());
    setState(() => _guardando = true);
    try {
      final ruta = await _recorder.stop();
      if (ruta == null) throw StateError('sin ruta');
      final bytes = await XFile(ruta).readAsBytes();
      HapticFeedback.mediumImpact();
      widget.onCambio(
        Grabacion(
          bytes: bytes,
          nombre: kIsWeb ? 'grabacion.wav' : 'grabacion.m4a',
          duracion: Duration(seconds: _segundos),
          ruta: kIsWeb ? null : ruta,
        ),
      );
      if (mounted) setState(() => _estado = EstadoGrabador.terminada);
    } catch (_) {
      if (mounted) {
        setState(() {
          _estado = EstadoGrabador.lista;
          _error = 'La grabación no se ha podido guardar. Vuelve a grabar.';
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Si está grabando o en pausa, termina y entrega lo grabado. Se llama al
  /// dejar el paso o cambiar de modo, para que no se pierda nada.
  Future<void> terminarSiGraba() async {
    if (_estado == EstadoGrabador.grabando || _estado == EstadoGrabador.pausa) await _terminar();
  }

  void _borrar() {
    widget.onCambio(null);
    setState(() {
      _estado = EstadoGrabador.lista;
      _segundos = 0;
      _niveles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GrabadorVista(
      estado: _estado,
      segundos: _estado == EstadoGrabador.terminada ? (widget.grabacion?.duracion.inSeconds ?? _segundos) : _segundos,
      niveles: _niveles,
      guardando: _guardando,
      error: _error,
      motivoPausa: _motivoPausa,
      grabacion: widget.grabacion,
      onEmpezar: _empezar,
      onPausar: _pausar,
      onSeguir: _seguir,
      onTerminar: _terminar,
      onBorrar: _borrar,
      onEscribir: widget.onEscribir,
      onReintentar: () => setState(() => _estado = EstadoGrabador.lista),
      onAbrirAjustes: widget.abrirAjustes,
    );
  }
}

class GrabadorVista extends StatelessWidget {
  const GrabadorVista({
    super.key,
    required this.estado,
    required this.segundos,
    required this.niveles,
    required this.onEmpezar,
    required this.onPausar,
    required this.onSeguir,
    required this.onTerminar,
    required this.onBorrar,
    required this.onEscribir,
    required this.onReintentar,
    this.onAbrirAjustes,
    this.grabacion,
    this.guardando = false,
    this.error,
    this.motivoPausa,
  });

  final EstadoGrabador estado;
  final int segundos;
  final List<double> niveles;
  final bool guardando;
  final String? error;
  final String? motivoPausa;
  final Grabacion? grabacion;
  final VoidCallback onEmpezar;
  final VoidCallback onPausar;
  final VoidCallback onSeguir;
  final VoidCallback onTerminar;
  final VoidCallback onBorrar;
  final VoidCallback onEscribir;
  final VoidCallback onReintentar;
  final Future<void> Function()? onAbrirAjustes;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    if (estado == EstadoGrabador.sinMicrofono) return _sinMicrofono(context);
    final grabando = estado == EstadoGrabador.grabando;
    final rotulo = switch (estado) {
      EstadoGrabador.grabando => 'Grabando',
      EstadoGrabador.pausa => 'En pausa',
      EstadoGrabador.terminada => 'Grabación terminada',
      _ => 'Lista para grabar',
    };
    final tiempo = '${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}';
    return Semantics(
      container: true,
      label: 'Grabador',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border.all(color: c.tinta, width: 2),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: c.sombra, offset: const Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        if (grabando) ...[
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(color: c.carmin, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (estado == EstadoGrabador.pausa) ...[
                          Icon(LucideIcons.pause, size: 18, color: c.tinta),
                          const SizedBox(width: 8),
                        ],
                        if (estado == EstadoGrabador.terminada) ...[
                          Icon(LucideIcons.circleCheck, size: 20, color: c.verde),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            rotulo,
                            style: letra.bodyMedium!.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: grabando ? c.carmin : c.tinta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('Hasta 60 min', style: letra.bodySmall!.copyWith(fontSize: 15, color: c.piedra)),
              ],
            ),
            if (estado == EstadoGrabador.pausa && motivoPausa != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.ficha,
                  border: Border(left: BorderSide(color: c.ocre, width: 6)),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(motivoPausa!, style: letra.bodySmall!.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            if (estado != EstadoGrabador.terminada) ...[
              const SizedBox(height: 10),
              Text(
                tiempo,
                textAlign: TextAlign.center,
                style: registro.copyWith(fontSize: 52, height: 1.05, letterSpacing: -1, color: c.tinta),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: _Medidor(niveles: niveles, activo: grabando),
              ),
            ],
            if (estado == EstadoGrabador.lista) ...[
              const SizedBox(height: 8),
              Center(child: _BotonGrabar(onPressed: guardando ? null : onEmpezar)),
              const SizedBox(height: 10),
              Text(
                'Pulsa para grabar',
                textAlign: TextAlign.center,
                style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Habla cerca del móvil. Puedes pausar cuando quieras.',
                textAlign: TextAlign.center,
                style: letra.bodySmall!.copyWith(color: c.piedra),
              ),
            ],
            if (grabando || estado == EstadoGrabador.pausa) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: grabando
                        ? BotonPlaca(
                            etiqueta: 'Pausar',
                            icono: LucideIcons.pause,
                            variante: VarianteBoton.secundario,
                            expandir: true,
                            onPressed: onPausar,
                          )
                        : BotonPlaca(
                            etiqueta: 'Seguir',
                            icono: LucideIcons.mic,
                            variante: VarianteBoton.secundario,
                            expandir: true,
                            onPressed: onSeguir,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BotonPlaca(
                      etiqueta: 'Terminar',
                      icono: LucideIcons.square,
                      expandir: true,
                      cargando: guardando ? 'Guardando…' : null,
                      onPressed: onTerminar,
                    ),
                  ),
                ],
              ),
            ],
            if (!kIsWeb && (grabando || estado == EstadoGrabador.pausa)) ...[
              const SizedBox(height: 10),
              Text(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? 'Puedes bloquear el móvil: la grabación sigue y lo verás en la pantalla de bloqueo.'
                    : 'Puedes bloquear el móvil: la grabación sigue y verás un aviso en la barra de notificaciones.',
                style: letra.bodySmall!.copyWith(color: c.piedra),
              ),
            ],
            if (estado == EstadoGrabador.terminada && grabacion != null) ...[
              const SizedBox(height: 12),
              Reproductor(url: grabacion!.url, titulo: 'Tu grabación'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: EnlaceDiscreto(
                  etiqueta: 'Borrar y grabar otra vez',
                  icono: LucideIcons.rotateCcw,
                  onPressed: onBorrar,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: letra.bodySmall!.copyWith(color: c.carmin, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sinMicrofono(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final ruta = ios
        ? 'Ajustes › Voces del Lugar › Micrófono'
        : 'Ajustes › Aplicaciones › Voces del Lugar › Permisos › Micrófono';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border.all(color: c.carmin, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.micOff, size: 24, color: c.carmin),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No podemos usar el micrófono',
                    style: letra.bodyMedium!.copyWith(fontSize: 19, fontWeight: FontWeight.w800, color: c.carmin),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (kIsWeb) ...[
              Text(
                'Tu navegador no ha dado permiso. Puedes darlo en el candado de la barra de direcciones y volver a intentarlo.',
                style: letra.bodyMedium!.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'Si la dirección no empieza por https://, el navegador nunca lo permite.',
                style: letra.bodySmall!.copyWith(color: c.piedra),
              ),
            ] else
              Text.rich(
                TextSpan(
                  text: 'Para grabar hace falta permiso para usar el micrófono. Puedes darlo en ',
                  children: [
                    TextSpan(
                      text: ruta,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: letra.bodyMedium!.copyWith(fontSize: 17),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (kIsWeb || onAbrirAjustes == null)
                  BotonPlaca(
                    etiqueta: 'Volver a intentarlo',
                    icono: LucideIcons.mic,
                    tamano: TamanoBoton.medio,
                    onPressed: onReintentar,
                  )
                else
                  BotonPlaca(
                    etiqueta: 'Abrir Ajustes',
                    icono: LucideIcons.settings,
                    tamano: TamanoBoton.medio,
                    onPressed: () {
                      onAbrirAjustes!();
                      onReintentar();
                    },
                  ),
                BotonPlaca(
                  etiqueta: 'Escribirla en su lugar',
                  variante: VarianteBoton.secundario,
                  tamano: TamanoBoton.medio,
                  onPressed: onEscribir,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de grabar: círculo carmín de 96, borde azulejo y anillo carmín.
class _BotonGrabar extends StatelessWidget {
  const _BotonGrabar({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return PlacaPulsable(
      onPressed: onPressed,
      etiqueta: 'Empezar a grabar',
      radio: 48,
      color: c.carmin,
      borde: c.carmin,
      sombra: BoxShadow(color: c.sombraBoton, offset: const Offset(3, 3)),
      minimo: const Size(96, 96),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.azulejo, width: 4),
        ),
        child: Icon(LucideIcons.mic, size: 40, color: c.sobreCarmin),
      ),
    );
  }
}

/// Medidor de voz: 28 barras con los últimos niveles del micrófono.
class _Medidor extends StatelessWidget {
  const _Medidor({required this.niveles, required this.activo});

  final List<double> niveles;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return SizedBox(
      height: 56,
      child: CustomPaint(
        painter: _BarrasVoz(niveles: List.of(niveles), color: activo ? c.anil : c.filete),
      ),
    );
  }
}

class _BarrasVoz extends CustomPainter {
  _BarrasVoz({required this.niveles, required this.color});

  final List<double> niveles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barras = 28;
    const ancho = 5.0;
    const hueco = 3.0;
    final total = barras * ancho + (barras - 1) * hueco;
    final inicio = (size.width - total) / 2;
    final pincel = Paint()..color = color;
    for (var i = 0; i < barras; i++) {
      final indice = niveles.length - barras + i;
      final nivel = indice >= 0 ? niveles[indice] : 0.0;
      final alto = niveles.isEmpty ? 6.0 : 8 + 44 * nivel;
      final x = inicio + i * (ancho + hueco);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, (size.height - alto) / 2, ancho, alto), const Radius.circular(2)),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_BarrasVoz old) => old.color != color || !listEquals(old.niveles, niveles);
}
