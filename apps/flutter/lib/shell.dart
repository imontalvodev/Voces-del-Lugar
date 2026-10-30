import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/contar_page.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/pages/revisar_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, this.inicial = Seccion.inicio});

  final VocesApi api;
  final Seccion inicial;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Seccion _seccion = widget.inicial;

  /// De dónde se vino a «Contar», para volver al salir.
  Seccion _antesDeContar = Seccion.inicio;
  final _mapKey = GlobalKey<MapPageState>();
  final _contarKey = GlobalKey<ContarPageState>();
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
    if (seccion == Seccion.contar) _antesDeContar = _seccion;
    setState(() => _seccion = seccion);
    if (kIsWeb) SystemNavigator.routeInformationUpdated(uri: Uri(path: seccion.ruta));
  }

  /// «Contar la historia de este sitio» desde el mapa.
  void _contarEn(LatLng punto, [String? nombre]) {
    _ir(Seccion.contar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _contarKey.currentState?.empezarEn(punto, nombre));
  }

  /// Atrás del sistema: en «Contar», el asistente va al paso anterior; si no,
  /// primero se deshace la pila de la sección y después se vuelve a Inicio.
  bool get _puedeSalir => _seccion == Seccion.inicio && !(_pila?.canPop() ?? false);

  void _atras() {
    final pila = _pila;
    if (pila != null && pila.canPop()) {
      pila.maybePop();
    } else if (_seccion == Seccion.contar) {
      _contarKey.currentState?.atras();
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
      onLeaveStory: () => _ir(Seccion.contar),
      onChanged: () => setState(() {}),
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
          Seccion.mapa: pila(Seccion.mapa, MapPage(key: _mapKey, api: widget.api, onLeaveStory: _contarEn)),
          Seccion.contar: pila(
            Seccion.contar,
            ContarPage(
              key: _contarKey,
              api: widget.api,
              onSalir: () => _ir(_antesDeContar == Seccion.contar ? Seccion.inicio : _antesDeContar),
              onVerLoHecho: () => _ir(Seccion.cuenta),
            ),
          ),
          Seccion.cuenta: pila(Seccion.cuenta, cuenta),
          Seccion.revisar: pila(Seccion.revisar, RevisarPage(api: widget.api)),
        },
      ),
    );
  }
}
