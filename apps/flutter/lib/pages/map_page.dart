import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/locate.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/buscador.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/permiso.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/placa_mapa.dart';
import 'package:voces/ui/teselas.dart';

/// Sin centro guardado ni ubicación, el mapa enseña España entera.
const _inicioPorDefecto = (centro: LatLng(40.2, -3.7), zoom: 6.0);

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.api,
    required this.onLeaveStory,
    this.locate = deviceLocation,
    this.permiso = locationPermission,
    this.abrirAjustes = openLocationSettings,
    this.conTeselas = true,
  });

  final VocesApi api;
  final void Function(LatLng point, [String? placeName]) onLeaveStory;
  final Future<LatLng?> Function({bool ask}) locate;
  final Future<String> Function() permiso;
  final Future<void> Function() abrirAjustes;

  /// En los tests no se piden teselas a la red.
  final bool conTeselas;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  VoidCallback? _flightStep;
  Timer? _debounce;
  List<StoryPin> _stories = [];
  String? _lugarId;
  LatLng? _pin;
  bool _lista = false;
  bool _ready = false;
  bool _cargando = true;
  bool _sinConexion = false;
  bool _sinUbicacion = false;
  bool _localizando = false;
  bool _colocando = false;
  int _reloadTicket = 0;
  ({LatLng centro, double zoom})? _inicio;

  /// Cuenta los movimientos de quien mira: si se mueve mientras se espera la
  /// posición, no se le arrastra.
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    widget.api.changes.addListener(reload);
    _cargarInicio();
  }

  @override
  void dispose() {
    widget.api.changes.removeListener(reload);
    _debounce?.cancel();
    _flight.dispose();
    super.dispose();
  }

  Future<void> _cargarInicio() async {
    var inicio = _inicioPorDefecto;
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getStringList('mapa_centro');
      if (guardado != null && guardado.length == 3) {
        inicio = (
          centro: LatLng(double.parse(guardado[0]), double.parse(guardado[1])),
          zoom: double.parse(guardado[2]),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _inicio = inicio);
  }

  Future<void> _guardarCentro() async {
    if (!_ready) return;
    final camara = _map.camera;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('mapa_centro', [
        '${camara.center.latitude}',
        '${camara.center.longitude}',
        '${camara.zoom}',
      ]);
    } catch (_) {}
  }

  /// Pide marcar el sitio exacto tocando el mapa (lo usa «Contar»).
  void beginPlacing() {
    setState(() {
      _colocando = true;
      _lugarId = null;
      _lista = false;
    });
  }

  /// Abre el mapa en un lugar con su vista previa («Ver en el mapa»).
  void mostrarLugar(String lugarId, LatLng punto) {
    _moves++;
    setState(() {
      _lugarId = lugarId;
      _pin = null;
      _lista = false;
      _colocando = false;
    });
    if (_ready) {
      _flyTo(punto, 16);
    } else {
      setState(() => _inicio = (centro: punto, zoom: 16));
    }
  }

  List<Lugar> get _lugares => lugaresDe(_stories);

  Lugar? get _lugar => _lugares.where((l) => l.id == _lugarId).firstOrNull;

  Future<void> reload() async {
    if (!_ready || !mounted) return;
    final ticket = ++_reloadTicket;
    final bounds = _map.camera.visibleBounds;
    // Muy alejado, el recuadro puede dar la vuelta al mundo: entonces se pide entero.
    final wraps = bounds.west >= bounds.east || bounds.east - bounds.west >= 360;
    try {
      final stories = await widget.api.mapStories(
        wraps ? -180 : bounds.west,
        bounds.south,
        wraps ? 180 : bounds.east,
        bounds.north,
      );
      if (!mounted || ticket != _reloadTicket) return;
      setState(() {
        _stories = stories;
        _sinConexion = false;
        if (_lugarId != null && stories.every((s) => s.placeId != _lugarId)) _lugarId = null;
      });
    } catch (_) {
      if (mounted && ticket == _reloadTicket) setState(() => _sinConexion = true);
    } finally {
      if (mounted && ticket == _reloadTicket) setState(() => _cargando = false);
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      reload();
      _guardarCentro();
    });
  }

  void _goToPlace(PlaceHit hit) {
    setState(() {
      _lugarId = null;
      _lista = false;
      _sinUbicacion = false;
    });
    _flyTo(hit.point, hit.isSettlement ? 14 : 16);
  }

  /// Al abrir, si ya hay permiso, el mapa empieza donde está quien mira.
  Future<void> _startNearUser() async {
    if (await widget.permiso() case 'whileInUse' || 'always') {
      final moves = _moves;
      final point = await widget.locate(ask: false);
      if (!mounted || point == null || moves != _moves) return;
      _flyTo(point, 14);
    }
  }

  /// «Aquí»: la ubicación se pide al pulsar, nunca al abrir la app, y antes
  /// una pantalla propia explica para qué.
  Future<void> _aqui() async {
    if (_localizando) return;
    final estado = await widget.permiso();
    if (!mounted) return;
    if (estado == 'whileInUse' || estado == 'always') return _localizar(pedir: false);
    if (estado == 'deniedForever' || estado == 'unableToDetermine') {
      setState(() => _sinUbicacion = true);
      return;
    }
    if (!kIsWeb) {
      final seguir = await explicarPermiso(
        context,
        icono: LucideIcons.mapPin,
        titulo: 'Para llevarte a donde estás',
        texto: 'Basta con saber más o menos dónde estás. Ahora tu móvil te lo preguntará.',
      );
      if (!seguir || !mounted) return;
    }
    await _localizar(pedir: true);
  }

  Future<void> _localizar({required bool pedir}) async {
    setState(() => _localizando = true);
    final moves = ++_moves;
    LatLng? point;
    try {
      // Si nadie contesta al aviso, el botón no se queda esperando.
      point = await widget.locate(ask: pedir).timeout(const Duration(seconds: 20), onTimeout: () => null);
    } finally {
      if (mounted) setState(() => _localizando = false);
    }
    if (!mounted) return;
    if (point == null) {
      setState(() => _sinUbicacion = true);
      return;
    }
    setState(() => _sinUbicacion = false);
    mostrarNotificacion(context, 'Te mostramos dónde estás.');
    if (moves == _moves) _flyTo(point, 15);
  }

  /// Vuela la cámara; con movimiento reducido salta sin animar.
  void _flyTo(LatLng to, double zoom) {
    if (!_ready) return;
    final from = _map.camera.center;
    final fromZoom = _map.camera.zoom;
    if (MediaQuery.disableAnimationsOf(context)) {
      _map.move(to, zoom);
      _scheduleReload();
      return;
    }
    final distanceKm = const Distance().as(LengthUnit.Kilometer, from, to);
    final dip = math.min(3.0, math.log(1 + distanceKm) / 2);
    final curve = CurvedAnimation(parent: _flight, curve: curvaVdl);
    if (_flightStep != null) _flight.removeListener(_flightStep!);
    _flightStep = () {
      final t = curve.value;
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lon = from.longitude + (to.longitude - from.longitude) * t;
      final z = fromZoom + (zoom - fromZoom) * t - dip * math.sin(math.pi * t);
      _map.move(LatLng(lat, lon), z);
    };
    _flight
      ..addListener(_flightStep!)
      ..forward(from: 0).whenComplete(_scheduleReload);
  }

  void _elegirLugar(Lugar lugar) {
    _moves++;
    setState(() {
      _lugarId = lugar.id;
      _pin = null;
      _lista = false;
      _colocando = false;
    });
    final zoom = math.max(_map.camera.zoom, 15.0);
    var target = lugar.punto;
    if (tamano(context) != Vdl.amplio) {
      // La hoja tapa el pie: el centro baja para que la placa quede arriba.
      final projected = _map.camera.projectAtZoom(target, zoom);
      target = _map.camera.unprojectAtZoom(projected.translate(0, MediaQuery.sizeOf(context).height * 0.15), zoom);
    }
    _flyTo(target, zoom);
  }

  void _tocarMapa(LatLng point) {
    _moves++;
    if (_lugarId != null || _lista) {
      setState(() {
        _lugarId = null;
        _lista = false;
      });
      return;
    }
    setState(() {
      _pin = point;
      _colocando = false;
    });
  }

  void _zoom(double delta) {
    _moves++;
    final camera = _map.camera;
    _flyTo(camera.center, (camera.zoom + delta).clamp(3.0, 18.0));
  }

  void _contarAqui() {
    final pin = _pin;
    if (pin == null) return;
    widget.onLeaveStory(pin);
  }

  void _cancelarPin() => setState(() => _pin = null);

  @override
  Widget build(BuildContext context) {
    if (_inicio == null) return const Center(child: Cargando(texto: 'Cargando el mapa…', bloques: 0));
    return tamano(context) == Vdl.amplio ? _amplio(context) : _compacto(context);
  }

  // ---- Móvil y tableta: mapa a pantalla completa con cabecera y hoja ----

  Widget _compacto(BuildContext context) {
    final c = VdlColors.of(context);
    return Stack(
      children: [
        Positioned.fill(child: _lienzo()),
        if (_cargando && _stories.isEmpty) const Center(child: _Cartel('Cargando el mapa…')),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.cal,
                  border: Border(bottom: BorderSide(color: c.anil, width: 2)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buscador()),
                              const SizedBox(width: 8),
                              _BotonAqui(localizando: _localizando, onPressed: _aqui),
                            ],
                          ),
                        ),
                        ..._avisos(context),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                  child: _Zoom(onZoom: _zoom),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerRight, child: _Atribucion()),
              _hoja(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hoja(BuildContext context) {
    final c = VdlColors.of(context);
    final lugar = _lugar;
    final alto = MediaQuery.sizeOf(context).height;
    Widget contenido;
    if (_lista) {
      final historias = lugar?.historias ?? _stories;
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      text: '${lugar?.nombre ?? 'En esta vista'} ',
                      children: [TextSpan(text: '· ${historias.length}', style: registro.copyWith(fontSize: 19))],
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              BotonCuadrado(
                etiqueta: 'Cerrar la lista',
                icono: LucideIcons.chevronDown,
                onPressed: () => setState(() => _lista = false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8, top: 4, right: 4),
              children: [
                for (final h in historias)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FichaHistoria.de(h, compacta: true, onTap: () => openStory(context, h)),
                  ),
              ],
            ),
          ),
        ],
      );
    } else if (lugar != null) {
      contenido = _VistaPrevia(lugar: lugar, onLista: () => setState(() => _lista = true));
    } else if (_pin != null) {
      contenido = _SitioNuevo(onContar: _contarAqui, onCancelar: _cancelarPin);
    } else if (_cargando) {
      contenido = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Buscando historias en esta zona…',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: c.piedra),
        ),
      );
    } else {
      contenido = PlacaPulsable(
        onPressed: () => setState(() => _lista = true),
        hunde: false,
        minimo: const Size(48, 56),
        alineacion: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'En esta vista ',
                  children: [TextSpan(text: '· ${_stories.length}', style: registro.copyWith(fontSize: 18))],
                ),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'Ver la lista',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w800, color: c.anil),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronUp, size: 22, color: c.anil),
          ],
        ),
      );
    }
    return GestureDetector(
      // Arrastrar la hoja hacia arriba abre la lista y hacia abajo la cierra;
      // lo mismo se puede hacer con sus botones.
      onVerticalDragEnd: (detalles) {
        final v = detalles.primaryVelocity ?? 0;
        if (v < -200 && !_lista) setState(() => _lista = true);
        if (v > 200) {
          setState(() {
            if (_lista) {
              _lista = false;
            } else {
              _lugarId = null;
              _pin = null;
            }
          });
        }
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: _lista ? alto * 0.78 : alto * 0.6),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border(top: BorderSide(color: c.anil, width: 2)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSize(
            duration: duracion(context, const Duration(milliseconds: 200)),
            curve: curvaVdl,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: c.filete, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _lista ? contenido : SingleChildScrollView(child: contenido),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Escritorio: panel de 460 y mapa al lado ----

  Widget _amplio(BuildContext context) {
    final c = VdlColors.of(context);
    final lugar = _lugar;
    final letra = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 460,
          decoration: BoxDecoration(
            color: c.cal,
            border: Border(right: BorderSide(color: c.tinta, width: 2)),
          ),
          child: Semantics(
            container: true,
            label: 'Historias en esta vista',
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                _buscador(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BotonPlaca(
                    etiqueta: _localizando ? 'Buscando dónde estás…' : 'Ir a donde estoy',
                    icono: LucideIcons.locateFixed,
                    variante: VarianteBoton.secundario,
                    tamano: TamanoBoton.medio,
                    onPressed: _localizando ? null : _aqui,
                  ),
                ),
                ..._avisos(context),
                if (lugar != null)
                  _Recuadro(
                    color: c.anil,
                    child: _VistaPrevia(lugar: lugar, compacta: true, onLista: () => setState(() => _lista = true)),
                  )
                else if (_pin != null)
                  _Recuadro(
                    color: c.ocre,
                    child: _SitioNuevo(onContar: _contarAqui, onCancelar: _cancelarPin),
                  ),
                const SizedBox(height: 26),
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      text: 'Historias en esta vista ',
                      children: [TextSpan(text: '· ${_stories.length}', style: registro.copyWith(fontSize: 19))],
                    ),
                    style: letra.bodyMedium!.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                if (_cargando)
                  const Cargando(texto: 'Buscando historias en esta zona…', bloques: 2)
                else if (_sinConexion)
                  const SizedBox.shrink()
                else if (_stories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Vacio(
                      titulo: 'Aquí todavía no hay historias',
                      texto: 'Toca el mapa en el sitio donde pasó algo para contarlo.',
                      icono: LucideIcons.mapPin,
                    ),
                  )
                else
                  for (final h in (_lista && lugar != null) ? lugar.historias : _stories)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: FichaHistoria.de(h, compacta: true, onTap: () => openStory(context, h)),
                    ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _lienzo()),
              if (_cargando && _stories.isEmpty) const Center(child: _Cartel('Cargando el mapa…')),
              Positioned(right: 24, top: 24, child: _Zoom(onZoom: _zoom)),
              const Positioned(right: 0, bottom: 0, child: _Atribucion(larga: true)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _avisos(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final ruta = ios
        ? 'Ajustes › Voces del Lugar › Ubicación'
        : 'Ajustes › Aplicaciones › Voces del Lugar › Permisos › Ubicación';
    return [
      if (_colocando) ...[
        const SizedBox(height: 10),
        Aviso(
          tono: TonoAviso.info,
          titulo: 'Toca el mapa en el sitio exacto',
          texto: 'Donde pasó lo que quieres contar. Puedes buscar antes el pueblo o el barrio.',
          accion: EnlaceDiscreto(etiqueta: 'Cancelar', onPressed: () => setState(() => _colocando = false)),
        ),
      ],
      if (_sinUbicacion) ...[
        const SizedBox(height: 10),
        if (kIsWeb)
          const Aviso(
            tono: TonoAviso.aviso,
            titulo: 'No sabemos dónde estás',
            texto: 'Tu navegador no ha dado permiso de ubicación. Busca el pueblo o barrio arriba.',
          )
        else
          Aviso(
            tono: TonoAviso.aviso,
            titulo: 'No sabemos dónde estás',
            texto: 'Busca el pueblo o barrio arriba, o da permiso en $ruta.',
            accion: BotonPlaca(
              etiqueta: 'Abrir Ajustes',
              icono: LucideIcons.settings,
              variante: VarianteBoton.secundario,
              tamano: TamanoBoton.medio,
              onPressed: widget.abrirAjustes,
            ),
          ),
      ],
      if (_sinConexion) ...[const SizedBox(height: 10), AvisoSinConexion(onRetry: reload)],
    ];
  }

  Widget _buscador() => BuscadorLugares(api: widget.api, onLugar: _goToPlace);

  Widget _lienzo() {
    final inicio = _inicio!;
    final lugar = _lugar;
    final escala = MediaQuery.textScalerOf(context);
    final otros = _lugares.where((l) => l.id != lugar?.id);
    Marker placa(Lugar l, bool elegida) {
      final medida = PlacaLugar.medida(l.nombre, escala);
      return Marker(
        point: l.punto,
        width: medida.width,
        height: medida.height,
        alignment: Alignment.topCenter,
        child: PlacaLugar(
          nombre: l.nombre,
          recuento: l.historias.length,
          elegida: elegida,
          onTap: () => elegida ? setState(() => _lista = true) : _elegirLugar(l),
        ),
      );
    }

    return Semantics(
      label: 'Mapa',
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: inicio.centro,
          initialZoom: inicio.zoom,
          minZoom: 3,
          maxZoom: 18.5,
          backgroundColor: VdlColors.of(context).cal,
          onMapReady: () {
            _ready = true;
            reload();
            _startNearUser();
          },
          onTap: (_, point) => _tocarMapa(point),
          onLongPress: (_, point) => setState(() {
            _pin = point;
            _lugarId = null;
            _lista = false;
          }),
          onMapEvent: (event) {
            if (event.source != MapEventSource.mapController && event.source != MapEventSource.nonRotatedSizeChange) {
              _moves++;
              _scheduleReload();
            }
          },
        ),
        children: [
          if (widget.conTeselas) teselasVdl(context),
          MarkerLayer(
            markers: [
              for (final l in otros) placa(l, false),
              if (lugar != null) placa(lugar, true),
              if (_pin != null)
                Marker(
                  point: _pin!,
                  width: PinNuevo.medida.width,
                  height: PinNuevo.medida.height,
                  alignment: const Alignment(0, -0.37),
                  child: const PinNuevo(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vista previa de un lugar elegido: su primera historia y, si hay más, el
/// enlace a la lista del sitio.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({required this.lugar, required this.onLista, this.compacta = false});

  final Lugar lugar;
  final VoidCallback onLista;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final h = lugar.historias.first;
    final n = lugar.historias.length;
    final datos = [
      categoryLabel(h.category),
      ?decadeLabel(h.decade),
      contadaPor(h.narratorName, h.narratorRelation, deceased: h.narratorDeceased),
    ].join(' · ');
    final duracion = duracionCorta(h.audioSeconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Semantics(
              header: true,
              child: Text(lugar.nombre, style: letra.titleLarge!.copyWith(color: c.anilHondo)),
            ),
            Text(recuentoHistorias(n), style: registro.copyWith(fontSize: 16, color: c.tinta)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.ficha,
            border: Border.all(color: c.tinta, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(h.title, style: letra.titleMedium!.copyWith(fontSize: 19, height: 1.25)),
              const SizedBox(height: 4),
              Text(
                datos,
                style: registro.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: c.piedra),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: BotonPlaca(
                  etiqueta: h.hasAudio ? (duracion == null ? 'Escuchar' : 'Escuchar · $duracion') : 'Leer la historia',
                  icono: h.hasAudio ? LucideIcons.play : LucideIcons.bookOpenText,
                  expandir: !compacta,
                  onPressed: () => openStory(context, h, escuchar: h.hasAudio),
                ),
              ),
            ],
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 6),
          PlacaPulsable(
            onPressed: onLista,
            hunde: false,
            alineacion: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ver las $n historias de este sitio',
                    style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: c.anil),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 22, color: c.anil),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Al tocar un sitio vacío: ¿pasó algo aquí?
class _SitioNuevo extends StatelessWidget {
  const _SitioNuevo({required this.onContar, required this.onCancelar});

  final VoidCallback onContar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final letra = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('Aquí todavía no hay historias', style: letra.titleLarge!.copyWith(fontSize: 22)),
        ),
        const SizedBox(height: 6),
        Text(
          '¿Pasó algo en este sitio que merezca recordarse?',
          style: letra.bodyMedium!.copyWith(fontSize: 17, color: VdlColors.of(context).piedra),
        ),
        const SizedBox(height: 14),
        BotonPlaca(
          etiqueta: 'Contar la historia de este sitio',
          icono: LucideIcons.mic,
          expandir: true,
          onPressed: onContar,
        ),
        const SizedBox(height: 8),
        Center(
          child: EnlaceDiscreto(etiqueta: 'Cancelar', onPressed: onCancelar),
        ),
      ],
    );
  }
}

class _Recuadro extends StatelessWidget {
  const _Recuadro({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VdlColors.of(context).azulejo,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: child,
    );
  }
}

/// «Aquí»: ir a donde está quien mira.
class _BotonAqui extends StatelessWidget {
  const _BotonAqui({required this.localizando, required this.onPressed});

  final bool localizando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Tooltip(
      message: 'Ir a donde estoy',
      excludeFromSemantics: true,
      child: PlacaPulsable(
        onPressed: localizando ? null : onPressed,
        etiqueta: localizando ? 'Buscando dónde estás' : 'Ir a donde estoy',
        color: c.azulejo,
        borde: c.anil,
        sombra: BoxShadow(color: c.sombraBoton, offset: const Offset(2, 2)),
        minimo: const Size(66, 54),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(localizando ? LucideIcons.hourglass : LucideIcons.locateFixed, size: 22, color: c.anil),
              Text(
                'Aquí',
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontSize: 15, height: 1.1, fontWeight: FontWeight.w800, color: c.anil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acercar y alejar con botones: el mapa no depende solo del gesto.
class _Zoom extends StatelessWidget {
  const _Zoom({required this.onZoom});

  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    Widget boton(String etiqueta, IconData icono, double delta) => Tooltip(
      message: etiqueta,
      excludeFromSemantics: true,
      child: PlacaPulsable(
        onPressed: () => onZoom(delta),
        etiqueta: etiqueta,
        radio: 0,
        minimo: const Size(52, 52),
        child: Icon(icono, size: 26, color: c.tinta),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border.all(color: c.tinta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          boton('Acercar', LucideIcons.plus, 1),
          Container(width: 52, height: 1.5, color: c.filete),
          boton('Alejar', LucideIcons.minus, -1),
        ],
      ),
    );
  }
}

class _Atribucion extends StatelessWidget {
  const _Atribucion({this.larga = false});

  final bool larga;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: c.azulejo,
      child: Text(
        larga ? '© colaboradores de OpenStreetMap' : '© OpenStreetMap',
        style: TextStyle(fontFamily: 'AtkinsonHyperlegibleNext', fontSize: 13, color: c.piedra),
      ),
    );
  }
}

class _Cartel extends StatelessWidget {
  const _Cartel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border.all(color: c.tinta, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
