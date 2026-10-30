import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/borrador.dart';
import 'package:voces/links.dart';
import 'package:voces/pages/entrar_page.dart';
import 'package:voces/permisos.dart';
import 'package:voces/permisos.dart' as permisos show permisoMicro, pedirMicro;
import 'package:voces/story_format.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/buscador.dart';
import 'package:voces/ui/campos.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/grabador.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/permiso.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/placa_mapa.dart';
import 'package:voces/ui/sello.dart';
import 'package:voces/ui/teselas.dart';

const _nombresPaso = ['Sitio', 'Historia', 'Quién', 'Permiso'];

/// Asistente «Contar» en cuatro pasos (Sitio, Historia, Quién y Permiso) y la
/// confirmación. El borrador se guarda en el dispositivo en cada paso.
class ContarPage extends StatefulWidget {
  const ContarPage({
    super.key,
    required this.api,
    required this.onSalir,
    required this.onVerLoHecho,
    this.conTeselas = true,
    this.permisoMicro = permisos.permisoMicro,
    this.pedirMicro = permisos.pedirMicro,
  });

  final VocesApi api;
  final VoidCallback onSalir;
  final VoidCallback onVerLoHecho;
  final bool conTeselas;
  final Future<EstadoPermiso> Function() permisoMicro;
  final Future<EstadoPermiso> Function() pedirMicro;

  @override
  State<ContarPage> createState() => ContarPageState();
}

class ContarPageState extends State<ContarPage> {
  Borrador _b = Borrador();
  int _paso = 1;
  final _mapa = MapController();
  final _sitio = TextEditingController();
  final _titulo = TextEditingController();
  final _epoca = TextEditingController();
  final _texto = TextEditingController();
  final _narrador = TextEditingController();
  final _parentesco = TextEditingController();
  final _desplazamiento = ScrollController();
  Grabacion? _grabacion;
  PlatformFile? _archivo;
  bool _intentoSitio = false;
  bool _intentoHistoria = false;
  bool _intentoGuardar = false;
  bool _guardando = false;
  bool _errorGuardar = false;
  StoryPin? _creada;
  bool _audioEnviado = false;
  bool _publicada = false;
  Timer? _guardado;

  @override
  void initState() {
    super.initState();
    for (final c in [_sitio, _titulo, _epoca, _texto, _narrador, _parentesco]) {
      c.addListener(_anotar);
    }
    _recuperar();
  }

  @override
  void dispose() {
    _guardado?.cancel();
    for (final c in [_sitio, _titulo, _epoca, _texto, _narrador, _parentesco]) {
      c.dispose();
    }
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _recuperar() async {
    final b = await Borrador.cargar();
    if (b == null || !mounted) return;
    Grabacion? grabacion;
    final ruta = b.audioRuta;
    if (ruta != null && !kIsWeb) {
      try {
        grabacion = Grabacion(
          bytes: await XFile(ruta).readAsBytes(),
          nombre: 'grabacion.m4a',
          duracion: Duration(seconds: b.audioSegundos ?? 0),
          ruta: ruta,
        );
      } catch (_) {
        b.audioRuta = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _b = b;
      _paso = b.paso;
      _grabacion = grabacion;
    });
    _sitio.text = b.sitio;
    _titulo.text = b.titulo;
    _epoca.text = b.epoca;
    _texto.text = b.texto;
    _narrador.text = b.narrador;
    _parentesco.text = b.parentesco;
  }

  /// Empieza en un sitio ya elegido en el mapa («Contar la historia de este sitio»).
  void empezarEn(LatLng punto, [String? nombre]) {
    setState(() {
      _paso = 1;
      _b
        ..lat = punto.latitude
        ..lng = punto.longitude;
    });
    if (nombre != null && _sitio.text.trim().isEmpty) _sitio.text = nombre;
    _anotar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapa.move(punto, 17);
      } catch (_) {}
    });
  }

  /// Cada cambio se apunta en el borrador; se guarda en el dispositivo enseguida.
  void _anotar() {
    _b
      ..sitio = _sitio.text
      ..titulo = _titulo.text
      ..epoca = _epoca.text
      ..texto = _texto.text
      ..narrador = _narrador.text
      ..parentesco = _parentesco.text
      ..paso = _paso.clamp(1, 4)
      ..audioRuta = _grabacion?.ruta
      ..audioSegundos = _grabacion?.duracion.inSeconds;
    _guardado?.cancel();
    _guardado = Timer(const Duration(milliseconds: 300), () => _b.guardar());
  }

  void _cambiar(VoidCallback cambio) {
    setState(cambio);
    _anotar();
  }

  LatLng? get _punto => _b.lat == null ? null : LatLng(_b.lat!, _b.lng!);

  bool get _sitioListo => _punto != null && _sitio.text.trim().isNotEmpty;

  bool get _hayHistoria => switch (_b.modo) {
    'grabar' => _grabacion != null,
    'escribir' => _texto.text.trim().isNotEmpty,
    _ => _archivo != null,
  };

  bool get _historiaLista => _hayHistoria && _titulo.text.trim().isNotEmpty && _b.tipo != null;

  void _irA(int paso) {
    _cambiar(() => _paso = paso);
    if (_desplazamiento.hasClients) _desplazamiento.jumpTo(0);
  }

  void _siguiente() {
    if (_paso == 1 && !_sitioListo) return setState(() => _intentoSitio = true);
    if (_paso == 2 && !_historiaLista) return setState(() => _intentoHistoria = true);
    _irA(_paso + 1);
  }

  /// Atrás del sistema o del asistente: paso anterior; en el primero, pregunta.
  Future<void> atras() async {
    if (_paso == 5) return _otra(salir: true);
    if (_paso > 1) return _irA(_paso - 1);
    await _salir();
  }

  Future<void> _salir() async {
    final salir = await confirmar(
      context,
      titulo: '¿Salir sin guardar?',
      mensaje: 'Lo que has grabado o escrito se perderá. Si sales, no se guarda nada.',
      si: 'Salir y borrar lo que llevo',
      no: 'Seguir contando',
      peligro: true,
    );
    if (salir) await _otra(salir: true);
  }

  Future<void> _otra({bool salir = false}) async {
    _guardado?.cancel();
    await Borrador.borrar();
    if (!mounted) return;
    setState(() {
      _b = Borrador();
      _paso = 1;
      _grabacion = null;
      _archivo = null;
      _intentoSitio = _intentoHistoria = _intentoGuardar = _errorGuardar = false;
      _creada = null;
      _audioEnviado = false;
      _publicada = false;
    });
    for (final c in [_sitio, _titulo, _epoca, _texto, _narrador, _parentesco]) {
      c.clear();
    }
    await Borrador.borrar();
    if (salir) widget.onSalir();
  }

  Future<bool> _entrar({bool caducada = false}) async {
    final hecho = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntrarPage(api: widget.api, sesionCaducada: caducada),
      ),
    );
    return hecho == true && widget.api.account != null;
  }

  Future<void> _guardar({bool publicar = false}) async {
    if (!_b.permiso) return setState(() => _intentoGuardar = true);
    // Sin sesión se pide entrar y se sigue sin perder nada.
    if (widget.api.account == null && !await _entrar()) return;
    setState(() {
      _guardando = true;
      _errorGuardar = false;
    });
    try {
      // Si un intento anterior ya creó la historia y falló al subir el audio,
      // se reintenta solo lo que faltaba: así no quedan historias repetidas.
      final previa = _creada;
      if (previa != null) {
        await widget.api.updateStory(
          previa.id,
          title: _titulo.text.trim(),
          body: _b.modo == 'escribir' ? _texto.text.trim() : '',
          narratorName: _narrador.text.trim(),
          narratorRelation: _parentesco.text.trim(),
        );
      }
      final creada = _creada ??= await widget.api.createStory(
        title: _titulo.text.trim(),
        body: _b.modo == 'escribir' ? _texto.text.trim() : '',
        narratorName: _narrador.text.trim(),
        relation: _parentesco.text.trim(),
        deceased: _b.fallecido,
        license: _b.licencia,
        placeName: _sitio.text.trim(),
        point: _punto!,
        category: _b.tipo ?? 'otro',
        decade: decadaDeEpoca(_epoca.text),
      );
      if (!_audioEnviado) {
        if (_b.modo == 'grabar' && _grabacion != null) {
          await widget.api.uploadAudio(creada.id, _grabacion!.nombre, _grabacion!.bytes);
        } else if (_b.modo == 'adjuntar' && _archivo != null) {
          await widget.api.uploadAudio(creada.id, _archivo!.name, await _archivo!.readAsBytes());
        }
        _audioEnviado = true;
      }
      final publica = publicar && (widget.api.account?.canModerate ?? false);
      if (publica) _creada = await widget.api.publish(creada.id);
      _guardado?.cancel();
      await Borrador.borrar();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _publicada = publica;
        _paso = 5;
      });
      if (_desplazamiento.hasClients) _desplazamiento.jumpTo(0);
      if (publica) mostrarNotificacion(context, 'Publicada. Ya está en el mapa.');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('caducado') || widget.api.account == null) {
        final otraVez = await confirmar(
          context,
          titulo: 'Tu sesión ha caducado',
          mensaje: 'Entra otra vez para guardarla. No perderás nada de lo que has grabado o escrito.',
          si: 'Entrar otra vez',
        );
        if (otraVez && await _entrar(caducada: true)) return _guardar(publicar: publicar);
      } else {
        setState(() => _errorGuardar = true);
      }
    } catch (_) {
      if (mounted) setState(() => _errorGuardar = true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Antes de que el móvil pregunte por el micrófono, una pantalla propia lo
  /// explica; si ya está dado o se negó para siempre, no hace falta.
  Future<bool> _explicarMicro() async {
    if (kIsWeb) return true;
    final estado = await widget.permisoMicro();
    if (estado != EstadoPermiso.preguntable || !mounted) return true;
    final seguir = await explicarPermiso(
      context,
      icono: LucideIcons.mic,
      titulo: 'Para grabar, la app necesita el micrófono',
      texto:
          'Solo se usa mientras grabas. Ahora tu móvil te lo preguntará: pulsa «Permitir». '
          'Si también pregunta por los avisos, permítelos: así verás que sigue grabando con el móvil bloqueado.',
    );
    if (seguir) await widget.pedirMicro();
    return seguir;
  }

  Future<void> _elegirArchivo() async {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'webm', 'aac'],
    );
    if (archivo != null) setState(() => _archivo = archivo);
  }

  @override
  Widget build(BuildContext context) {
    final amplio = tamano(context) == Vdl.amplio;
    final cuerpo = switch (_paso) {
      1 => _pasoSitio(context),
      2 => _pasoHistoria(context),
      3 => _pasoQuien(context),
      4 => _pasoPermiso(context),
      _ => _hecho(context),
    };
    final pie = _paso <= 4 ? _pie(context) : null;
    final moderador = widget.api.account?.canModerate ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) atras();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_paso <= 4) _cabecera(context),
              Expanded(
                child: SingleChildScrollView(
                  controller: _desplazamiento,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: amplio
                            ? const EdgeInsets.fromLTRB(48, 28, 48, 56)
                            : const EdgeInsets.fromLTRB(16, 18, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (amplio)
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: VdlColors.of(context).azulejo,
                                  border: Border.all(color: VdlColors.of(context).tinta, width: 1.5),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(color: VdlColors.of(context).sombra, offset: const Offset(4, 4)),
                                  ],
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cuerpo, ?pie]),
                              )
                            else
                              cuerpo,
                            if (!amplio && _paso == 4 && moderador) ...[
                              const SizedBox(height: 16),
                              BotonPlaca(
                                etiqueta: 'Guardar y publicar en el mapa',
                                variante: VarianteBoton.secundario,
                                expandir: true,
                                onPressed: _guardando ? null : () => _guardar(publicar: true),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Solo para moderadores.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(fontSize: 15, color: VdlColors.of(context).piedra),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: amplio ? null : pie,
      ),
    );
  }

  Widget _cabecera(BuildContext context) {
    final c = VdlColors.of(context);
    final amplio = tamano(context) == Vdl.amplio;
    return Container(
      padding: amplio ? const EdgeInsets.fromLTRB(48, 20, 48, 0) : const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: amplio
          ? null
          : BoxDecoration(
              color: c.cal,
              border: Border(bottom: BorderSide(color: c.filete, width: 1.5)),
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (amplio) ...[const Marca(), const SizedBox(width: 16)],
                  Expanded(
                    child: Text(
                      'Contar una historia',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  EnlaceDiscreto(etiqueta: 'Salir', icono: LucideIcons.x, onPressed: _salir),
                ],
              ),
              const SizedBox(height: 6),
              BarraPasos(paso: _paso),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final c = VdlColors.of(context);
    final amplio = tamano(context) == Vdl.amplio;
    final moderador = widget.api.account?.canModerate ?? false;
    final siguiente = _paso < 4
        ? BotonPlaca(
            etiqueta: 'Siguiente: ${_paso == 2 ? 'quién la cuenta' : _nombresPaso[_paso].toLowerCase()}',
            expandir: !amplio,
            onPressed: _siguiente,
          )
        : BotonPlaca(
            etiqueta: 'Guardar la historia',
            cargando: _guardando ? 'Guardando…' : null,
            expandir: !amplio,
            onPressed: () => _guardar(),
          );
    final atras = _paso > 1
        ? BotonPlaca(
            etiqueta: 'Atrás',
            icono: LucideIcons.arrowLeft,
            variante: VarianteBoton.secundario,
            onPressed: _guardando ? null : () => _irA(_paso - 1),
          )
        : null;
    final fila = Row(
      children: [
        ?atras,
        if (atras != null) const SizedBox(width: 10),
        if (amplio) ...[
          const Spacer(),
          if (_paso == 4 && moderador) ...[
            BotonPlaca(
              etiqueta: 'Guardar y publicar en el mapa',
              variante: VarianteBoton.secundario,
              onPressed: _guardando ? null : () => _guardar(publicar: true),
            ),
            const SizedBox(width: 10),
          ],
          siguiente,
        ] else
          Expanded(child: siguiente),
      ],
    );
    if (amplio) {
      return Container(
        margin: const EdgeInsets.only(top: 28),
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.filete, width: 1.5)),
        ),
        child: fila,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border(top: BorderSide(color: c.tinta, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: fila),
      ),
    );
  }

  // ---- Paso 1: Sitio ----

  Widget _pasoSitio(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final punto = _punto;
    final amplio = tamano(context) == Vdl.amplio;
    final error = _intentoSitio && punto == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloPantalla('¿Dónde pasó?'),
        const Entradilla('Toca el mapa en el sitio exacto. Puedes acercarte con los botones + y −.'),
        const SizedBox(height: 14),
        BuscadorLugares(api: widget.api, onLugar: (lugar) => _mapa.move(lugar.point, lugar.isSettlement ? 15 : 17)),
        const SizedBox(height: 12),
        Container(
          height: amplio ? 420 : 300,
          decoration: BoxDecoration(
            border: Border.all(color: error ? c.carmin : c.tinta, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Semantics(
                  label: 'Mapa: toca donde pasó la historia',
                  child: FlutterMap(
                    mapController: _mapa,
                    options: MapOptions(
                      initialCenter: punto ?? const LatLng(40.2, -3.7),
                      initialZoom: punto == null ? 6 : 17,
                      backgroundColor: c.cal,
                      onTap: (_, p) => _cambiar(() {
                        _b
                          ..lat = p.latitude
                          ..lng = p.longitude;
                      }),
                    ),
                    children: [
                      if (widget.conTeselas) teselasVdl(context),
                      MarkerLayer(
                        markers: [
                          if (punto != null)
                            Marker(
                              point: punto,
                              width: PinNuevo.medida.width,
                              height: PinNuevo.medida.height,
                              alignment: const Alignment(0, -0.37),
                              child: const PinNuevo(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _ZoomMini(
                    onZoom: (d) {
                      final cam = _mapa.camera;
                      _mapa.move(cam.center, (cam.zoom + d).clamp(3.0, 18.5));
                    },
                  ),
                ),
                if (punto == null)
                  Positioned(
                    left: 10,
                    right: 80,
                    bottom: 10,
                    // El mapa ya lo dice en su etiqueta; aquí solo se ve.
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.azulejo,
                            border: Border.all(color: c.tinta, width: 1.5),
                          ),
                          child: Text(
                            'Toca el mapa para marcar el sitio',
                            style: letra.bodySmall!.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Positioned(right: 0, bottom: 0, child: _AtribucionMini()),
              ],
            ),
          ),
        ),
        if (error) ...[const SizedBox(height: 8), const MensajeError('Marca en el mapa dónde pasó.')],
        if (punto != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, size: 20, color: c.ocreTinta),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sitio marcado. Si no es ahí, toca otra vez.',
                    style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        CampoTexto(
          etiqueta: '¿Cómo lo llamáis allí?',
          ayuda: 'Por ejemplo: «el lavadero», «la casa de la esquina».',
          controller: _sitio,
          maximo: 160,
          error: _intentoSitio && _sitio.text.trim().isEmpty ? 'Escribe el nombre del sitio.' : null,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ---- Paso 2: Historia ----

  Widget _pasoHistoria(BuildContext context) {
    final letra = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloPantalla('Cuéntala'),
        const Entradilla('Con grabarla basta. Si lo prefieres, puedes escribirla o subir una grabación que ya tengas.'),
        const SizedBox(height: 16),
        _Modos(modo: _b.modo, onModo: (m) => _cambiar(() => _b.modo = m)),
        const SizedBox(height: 16),
        switch (_b.modo) {
          'escribir' => CampoTexto(
            etiqueta: 'La historia',
            controller: _texto,
            lineas: 8,
            onChanged: (_) => setState(() {}),
          ),
          'adjuntar' => _Adjunto(
            archivo: _archivo,
            onElegir: _elegirArchivo,
            onQuitar: () => setState(() => _archivo = null),
          ),
          _ => Grabador(
            grabacion: _grabacion,
            onCambio: (g) => _cambiar(() => _grabacion = g),
            onEscribir: () => _cambiar(() => _b.modo = 'escribir'),
            antesDePedir: _explicarMicro,
            abrirAjustes: abrirAjustesApp,
          ),
        },
        if (_intentoHistoria && !_hayHistoria) ...[
          const SizedBox(height: 8),
          const MensajeError('Falta la historia: grábala, escríbela o sube un audio.'),
        ],
        const SizedBox(height: 22),
        CampoTexto(
          etiqueta: 'Título',
          ayuda: 'Una frase que la resuma.',
          controller: _titulo,
          maximo: 180,
          error: _intentoHistoria && _titulo.text.trim().isEmpty ? 'Ponle un título.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        Text('¿Qué tipo de historia es?', style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          label: '¿Qué tipo de historia es?',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tipo in storyCategories)
                ChipTipo(categoria: tipo, elegido: _b.tipo == tipo, onPressed: () => _cambiar(() => _b.tipo = tipo)),
            ],
          ),
        ),
        if (_intentoHistoria && _b.tipo == null) ...[const SizedBox(height: 8), const MensajeError('Elige un tipo.')],
        const SizedBox(height: 18),
        CampoTexto(
          etiqueta: '¿Cuándo pasó?',
          opcional: true,
          ayuda: 'Por ejemplo: «Años 50» o «Década de 1920».',
          controller: _epoca,
          maximo: 40,
        ),
      ],
    );
  }

  // ---- Paso 3: Quién ----

  Widget _pasoQuien(BuildContext context) {
    final c = VdlColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloPantalla('¿Quién la cuenta?'),
        const Entradilla('La persona que vivió la historia o que la conoce.'),
        const SizedBox(height: 18),
        CampoTexto(
          etiqueta: 'Nombre',
          opcional: true,
          ayuda: 'Si lo dejas vacío, aparecerá sin nombre.',
          controller: _narrador,
          maximo: 160,
          mayusculas: TextCapitalization.words,
        ),
        const SizedBox(height: 18),
        CampoTexto(
          etiqueta: '¿Qué es tuyo?',
          opcional: true,
          ayuda: 'Mi abuela, un vecino, yo mismo…',
          controller: _parentesco,
          maximo: 80,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.filete, width: 1.5)),
          ),
          child: Casilla(
            marcada: _b.fallecido,
            etiqueta: 'Ya ha fallecido',
            descripcion: 'En ese caso, el permiso para publicarla lo da su familia.',
            onChanged: (v) => _cambiar(() => _b.fallecido = v),
          ),
        ),
      ],
    );
  }

  // ---- Paso 4: Permiso ----

  Widget _pasoPermiso(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final sinPermiso = _intentoGuardar && !_b.permiso;
    final nombre = _narrador.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloPantalla('Permiso'),
        const Entradilla('Quien cuenta la historia decide si se publica y cómo se puede usar.'),
        if (_errorGuardar) ...[
          const SizedBox(height: 14),
          Aviso(
            tono: TonoAviso.error,
            titulo: 'No se ha podido guardar',
            texto: 'Tu historia sigue aquí, no se ha perdido nada. Revisa la conexión.',
            accion: BotonPlaca(
              etiqueta: 'Volver a intentarlo',
              variante: VarianteBoton.secundario,
              tamano: TamanoBoton.medio,
              onPressed: () => _guardar(),
            ),
          ),
        ],
        if (_b.fallecido) ...[
          const SizedBox(height: 14),
          Aviso(
            tono: TonoAviso.info,
            titulo: 'El permiso lo da la familia',
            texto:
                'Como ${nombre.isEmpty ? 'quien la cuenta' : nombre} ya ha fallecido, confirma que su familia está de acuerdo.',
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: c.azulejo,
            border: Border.all(color: sinPermiso ? c.carmin : c.tinta, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Casilla(
            marcada: _b.permiso,
            etiqueta: _b.fallecido
                ? 'Su familia me ha dado permiso para publicarla'
                : 'Quien la cuenta me ha dado permiso para publicarla',
            descripcion: 'Es obligatorio. Sin permiso, la historia no se puede guardar.',
            error: sinPermiso ? 'Marca la casilla para confirmar el permiso.' : null,
            onChanged: (v) => _cambiar(() => _b.permiso = v),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            '¿Cómo se puede usar?',
            style: letra.bodyMedium!.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        for (final (licencia, recomendada) in [('CC-BY-SA-4.0', true), ('CC-BY-4.0', false), ('CC0-1.0', false)]) ...[
          OpcionLicencia(
            elegida: _b.licencia == licencia,
            titulo: '${licenciaLlana(licencia).nombre}${recomendada ? ' (recomendada)' : ''}',
            sigla: licenseLabel(licencia),
            descripcion: licenciaLlana(licencia).detalle,
            onSelected: () => _cambiar(() => _b.licencia = licencia),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ---- Hecho ----

  Widget _hecho(BuildContext context) {
    final c = VdlColors.of(context);
    final amplio = tamano(context) == Vdl.amplio;
    final creada = _creada;
    final botones = [
      BotonPlaca(
        etiqueta: 'Ver lo que he dejado',
        icono: LucideIcons.listChecks,
        expandir: !amplio,
        onPressed: () async {
          await _otra();
          widget.onVerLoHecho();
        },
      ),
      BotonPlaca(
        etiqueta: 'Contar otra historia',
        variante: VarianteBoton.secundario,
        expandir: !amplio,
        onPressed: _otra,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: amplio ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: amplio ? Alignment.centerLeft : Alignment.center,
            child: Sello(_publicada ? EstadoSello.publicada : EstadoSello.enRevision, grande: true),
          ),
          const SizedBox(height: 18),
          const TituloPantalla('Gracias. Tu historia está guardada.'),
          const SizedBox(height: 10),
          Text(
            _publicada ? 'Ya está en el mapa. Cualquiera puede verla y escucharla.' : 'Ahora la revisa una persona del equipo. Cuando la publique, aparecerá en el mapa. Mientras tanto, puedes corregirla desde tu cuenta.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.piedra),
          ),
          if (creada != null) ...[
            const SizedBox(height: 18),
            FichaHistoria.de(
              creada,
              sello: _publicada ? null : EstadoSello.enRevision,
              onTap: () => openStory(context, creada),
            ),
          ],
          const SizedBox(height: 22),
          if (amplio)
            Wrap(spacing: 10, runSpacing: 10, children: botones)
          else
            Column(children: [botones[0], const SizedBox(height: 10), botones[1]]),
        ],
      ),
    );
  }
}

/// Barra de pasos con sus nombres: «Paso 2 de 4: Historia».
class BarraPasos extends StatelessWidget {
  const BarraPasos({super.key, required this.paso});

  final int paso;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Semantics(
      label: 'Paso $paso de 4: ${_nombresPaso[paso - 1]}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paso $paso de 4', style: registro.copyWith(fontSize: 16, color: c.tinta)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 4; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= paso ? c.anil : c.filete,
                          borderRadius: BorderRadius.circular(1),
                          border: i == paso ? Border.all(color: c.anilHondo, width: 2) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${i < paso ? '✓ ' : ''}${_nombresPaso[i - 1]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: letra.bodySmall!.copyWith(
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: i == paso ? FontWeight.w800 : FontWeight.w600,
                          color: i > paso ? c.piedra : c.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Grabar, Escribir o Subir audio.
class _Modos extends StatelessWidget {
  const _Modos({required this.modo, required this.onModo});

  final String modo;
  final ValueChanged<String> onModo;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    const modos = [
      ('grabar', 'Grabar', LucideIcons.mic),
      ('escribir', 'Escribir', LucideIcons.penLine),
      ('adjuntar', 'Subir audio', LucideIcons.paperclip),
    ];
    return Semantics(
      container: true,
      label: 'Cómo la cuentas',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: c.tinta, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                [
                  for (final (id, nombre, icono) in modos)
                    Expanded(
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: modo == id,
                        child: PlacaPulsable(
                          onPressed: () => onModo(id),
                          hunde: false,
                          radio: 0,
                          seleccionado: modo == id,
                          color: modo == id ? c.anil : c.azulejo,
                          minimo: const Size(48, 64),
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icono, size: 22, color: modo == id ? c.sobreAnil : c.tinta),
                                const SizedBox(height: 2),
                                Text(
                                  nombre,
                                  textAlign: TextAlign.center,
                                  style: letra.bodySmall!.copyWith(
                                    height: 1.2,
                                    fontWeight: modo == id ? FontWeight.w800 : FontWeight.w600,
                                    color: modo == id ? c.sobreAnil : c.tinta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ].fold<List<Widget>>([], (lista, w) {
                  if (lista.isNotEmpty) lista.add(Container(width: 2, color: c.tinta));
                  return lista..add(w);
                }),
          ),
        ),
      ),
    );
  }
}

class _Adjunto extends StatelessWidget {
  const _Adjunto({required this.archivo, required this.onElegir, required this.onQuitar});

  final PlatformFile? archivo;
  final VoidCallback onElegir;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final elegido = archivo;
    if (elegido != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border.all(color: c.tinta, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.fileHeadphone, size: 28, color: c.tinta),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(elegido.name, style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    'Listo para subir',
                    style: registro.copyWith(fontWeight: FontWeight.w400, color: c.piedra),
                  ),
                ],
              ),
            ),
            BotonCuadrado(etiqueta: 'Quitar el archivo', icono: LucideIcons.x, onPressed: onQuitar),
          ],
        ),
      );
    }
    return CustomPaint(
      painter: BordeSello(color: c.tinta, discontinuo: true, radio: 2),
      child: PlacaPulsable(
        onPressed: onElegir,
        hunde: false,
        radio: 2,
        color: c.azulejo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          children: [
            Icon(LucideIcons.paperclip, size: 30, color: c.tinta),
            const SizedBox(height: 6),
            Text('Elegir un archivo de audio', style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w800)),
            Text('MP3, M4A, WAV u OGG. Hasta 25 MB.', style: letra.bodySmall!.copyWith(color: c.piedra)),
          ],
        ),
      ),
    );
  }
}

class _ZoomMini extends StatelessWidget {
  const _ZoomMini({required this.onZoom});

  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border.all(color: c.tinta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Acercar',
            excludeFromSemantics: true,
            child: PlacaPulsable(
              onPressed: () => onZoom(1),
              etiqueta: 'Acercar',
              radio: 0,
              minimo: const Size(48, 48),
              child: Icon(LucideIcons.plus, size: 24, color: c.tinta),
            ),
          ),
          Container(width: 48, height: 1.5, color: c.filete),
          Tooltip(
            message: 'Alejar',
            excludeFromSemantics: true,
            child: PlacaPulsable(
              onPressed: () => onZoom(-1),
              etiqueta: 'Alejar',
              radio: 0,
              minimo: const Size(48, 48),
              child: Icon(LucideIcons.minus, size: 24, color: c.tinta),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtribucionMini extends StatelessWidget {
  const _AtribucionMini();

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: c.azulejo,
      child: Text(
        '© OpenStreetMap',
        style: TextStyle(fontFamily: 'AtkinsonHyperlegibleNext', fontSize: 13, color: c.piedra),
      ),
    );
  }
}
