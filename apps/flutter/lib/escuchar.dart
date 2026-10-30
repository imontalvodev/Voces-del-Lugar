import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Controles del sistema para lo que se está escuchando: pantalla de
/// bloqueo en iOS y notificación multimedia en Android, con título,
/// narrador y saltos de 10 s. Sigue sonando con la pantalla apagada.
///
/// El reproductor que suena se conecta con [conectar]; solo hay uno a la vez.
class Escucha extends BaseAudioHandler with SeekHandler {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];

  static const salto = Duration(seconds: 10);

  void conectar(AudioPlayer player, {required String titulo, String? narrador, Duration? duracion}) {
    if (!identical(_player, player)) {
      _soltar();
      _player = player;
      _subs
        ..add(player.playbackEventStream.listen((_) => _emitir()))
        ..add(player.playingStream.listen((_) => _emitir()))
        ..add(player.durationStream.listen((d) => _medio(titulo, narrador, d)));
    }
    _medio(titulo, narrador, duracion ?? player.duration);
    _emitir();
  }

  void desconectar(AudioPlayer player) {
    if (!identical(_player, player)) return;
    _soltar();
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
  }

  void _soltar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player = null;
  }

  void _medio(String titulo, String? narrador, Duration? duracion) {
    mediaItem.add(
      MediaItem(
        id: titulo,
        title: titulo,
        artist: narrador ?? 'Voces del Lugar',
        album: 'Voces del Lugar',
        duration: duracion,
      ),
    );
  }

  void _emitir() {
    final p = _player;
    if (p == null) return;
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.rewind, p.playing ? MediaControl.pause : MediaControl.play, MediaControl.fastForward],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (p.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: p.playing,
        updatePosition: p.position,
        bufferedPosition: p.bufferedPosition,
        speed: p.speed,
      ),
    );
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> stop() async {
    await _player?.pause();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> rewind() async {
    final p = _player;
    if (p == null) return;
    final atras = p.position - salto;
    await p.seek(atras < Duration.zero ? Duration.zero : atras);
  }

  @override
  Future<void> fastForward() async {
    final p = _player;
    if (p == null) return;
    final total = p.duration;
    final adelante = p.position + salto;
    await p.seek(total != null && adelante > total ? total : adelante);
  }
}

/// El manejador de la app; nulo en web y en los tests.
Escucha? escucha;

/// Arranca los controles del sistema (en Android e iOS) y la sesión de audio.
Future<void> iniciarEscucha() async {
  if (kIsWeb) return;
  try {
    escucha = await AudioService.init(
      builder: Escucha.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'org.vocesdellugar.escuchar',
        androidNotificationChannelName: 'Escuchar',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        fastForwardInterval: Escucha.salto,
        rewindInterval: Escucha.salto,
      ),
    );
    final sesion = await AudioSession.instance;
    await sesion.configure(const AudioSessionConfiguration.speech());
  } catch (_) {
    escucha = null;
  }
}
