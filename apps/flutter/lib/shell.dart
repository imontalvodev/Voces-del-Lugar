import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/compose_page.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, this.inicial = Seccion.inicio});

  final VocesApi api;
  final Seccion inicial;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Seccion _seccion = widget.inicial;
  LatLng? _pendingPoint;
  String? _pendingPlace;
  final _mapKey = GlobalKey<MapPageState>();
  final _pilas = {for (final s in Seccion.values) s: GlobalKey<NavigatorState>()};

  NavigatorState? get _pila => _pilas[_seccion]!.currentState;

  @override
  void initState() {
    super.initState();
    rumbo.addListener(_seguirRumbo);
  }

  @override
  void dispose() {
    rumbo.removeListener(_seguirRumbo);
    super.dispose();
  }

  /// Otra pantalla pide ir a una sección o a un lugar del mapa.
  void _seguirRumbo() {
    final pedido = rumbo.value;
    if (pedido == null || !mounted) return;
    rumbo.value = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _pilas[pedido.seccion]!.currentState?.popUntil((route) => route.isFirst);
    if (pedido.seccion != _seccion) _ir(pedido.seccion);
    final lugar = pedido.lugarId;
    final punto = pedido.punto;
    if (pedido.seccion == Seccion.mapa && lugar != null && punto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mapKey.currentState?.mostrarLugar(lugar, punto));
    }
  }

  void _ir(Seccion seccion) {
    if (seccion == _seccion) {
      _pila?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _seccion = seccion);
    if (kIsWeb) SystemNavigator.routeInformationUpdated(uri: Uri(path: seccion.ruta));
  }

  void _choosePointOnMap() {
    _ir(Seccion.mapa);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mapKey.currentState?.beginPlacing());
  }

  Future<void> _leaveStory(LatLng point, [String? placeName]) async {
    if (widget.api.account == null) {
      _pendingPoint = point;
      _pendingPlace = placeName;
      _ir(Seccion.cuenta);
      mostrarNotificacion(context, 'Entra o crea una cuenta y seguimos con la historia de ese sitio.');
      return;
    }
    _pendingPoint = null;
    _pendingPlace = null;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ComposePage(api: widget.api, point: point, placeName: placeName),
      ),
    );
    if (created == true) _mapKey.currentState?.reload();
  }

  /// Atrás del sistema: primero se deshace la pila de la sección; después se
  /// vuelve a Inicio; desde Inicio, sale de la app.
  bool get _puedeSalir => _seccion == Seccion.inicio && !(_pila?.canPop() ?? false);

  void _atras() {
    final pila = _pila;
    if (pila != null && pila.canPop()) {
      pila.maybePop();
    } else if (_seccion != Seccion.inicio) {
      _ir(Seccion.inicio);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pila(Seccion s, Widget raiz) =>
        PilaSeccion(navigatorKey: _pilas[s]!, raiz: raiz, onCambio: () => mounted ? setState(() {}) : null);
    final cuenta = AccountPage(
      api: widget.api,
      onLeaveStory: _choosePointOnMap,
      onChanged: () {
        setState(() {});
        final pending = _pendingPoint;
        if (pending != null && widget.api.account != null) _leaveStory(pending, _pendingPlace);
      },
    );
    return PopScope(
      canPop: _puedeSalir,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Armazon(
        seccion: _seccion,
        onSeccion: _ir,
        moderador: widget.api.account?.canModerate ?? false,
        paginas: {
          Seccion.inicio: pila(
            Seccion.inicio,
            HomePage(api: widget.api, onLeaveStory: () => _ir(Seccion.contar), onOpenMap: () => _ir(Seccion.mapa)),
          ),
          Seccion.mapa: pila(Seccion.mapa, MapPage(key: _mapKey, api: widget.api, onLeaveStory: _leaveStory)),
          Seccion.contar: pila(
            Seccion.contar,
            _ContarProvisional(onElegirSitio: _choosePointOnMap, onSalir: () => _ir(Seccion.inicio)),
          ),
          Seccion.cuenta: pila(Seccion.cuenta, cuenta),
          Seccion.revisar: pila(Seccion.revisar, cuenta),
        },
      ),
    );
  }
}

/// Entrada a «Contar» hasta que el asistente tenga su paso de sitio.
class _ContarProvisional extends StatelessWidget {
  const _ContarProvisional({required this.onElegirSitio, required this.onSalir});

  final VoidCallback onElegirSitio;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: MargenPagina(
          ancho: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EnlaceDiscreto(etiqueta: 'Volver', icono: LucideIcons.arrowLeft, onPressed: onSalir),
              const SizedBox(height: 12),
              const TituloPantalla('Contar una historia'),
              const Entradilla('Empieza por el sitio: toca el mapa donde pasó.'),
              const SizedBox(height: 24),
              BotonPlaca(
                etiqueta: 'Elegir el sitio en el mapa',
                icono: LucideIcons.mapPin,
                expandir: true,
                onPressed: onElegirSitio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
