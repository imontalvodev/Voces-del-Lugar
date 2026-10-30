import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:voces/api.dart';
import 'package:voces/avisos_push.dart';
import 'package:voces/duraciones.dart';
import 'package:voces/escuchar.dart';
import 'package:voces/links.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/notis.dart';
import 'package:voces/pages/bienvenida_page.dart';
import 'package:voces/shell.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/pagina.dart';

Future<void> main(List<String> args) async {
  // UnifiedPush despierta la app sin pantalla para entregar un aviso: solo
  // hace falta lo que lo recibe y lo enseña.
  if (args.contains('--unifiedpush-bg')) {
    WidgetsFlutterBinding.ensureInitialized();
    final api = VocesApi();
    await api.restore();
    await AvisosPush(api: api, canal: canalDeLaPlataforma()).iniciar();
    return;
  }
  usePathUrlStrategy(); // /historia/<id> en vez de /#/historia/<id>
  WidgetsFlutterBinding.ensureInitialized();
  final letra = await PreferenciaLetra.cargar();
  await iniciarEscucha();
  await Duraciones.cargar();
  runApp(VocesApp(letra: letra));
}

class VocesApp extends StatefulWidget {
  const VocesApp({super.key, required this.letra});

  final PreferenciaLetra letra;

  @override
  State<VocesApp> createState() => _VocesAppState();
}

class _VocesAppState extends State<VocesApp> {
  final _api = VocesApi();
  final _navegador = GlobalKey<NavigatorState>();
  late final _avisos = AvisosPush(api: _api, canal: canalDeLaPlataforma())..alAbrir = _abrirHistoria;
  String? _cuenta;
  var _ready = false;

  /// La sección de la dirección por la que se entra (en web, la barra).
  final _inicial = seccionDeRuta(WidgetsBinding.instance.platformDispatcher.defaultRouteName);

  /// Primer arranque: antes de nada, la bienvenida con el tamaño de letra.
  var _bienvenida = false;

  @override
  void initState() {
    super.initState();
    AvisosPush.instancia = _avisos;
    _api.changes.addListener(_cambioDeCuenta);
    Future.wait([_api.restore(), bienvenidaVista().then((vista) => _bienvenida = !vista)]).whenComplete(() async {
      if (!mounted) return;
      _cuenta = _api.account?.id;
      setState(() => _ready = true);
      await _avisos.iniciar();
      final inicial = Notis.historiaInicial;
      Notis.historiaInicial = null;
      if (inicial != null) _abrirHistoria(inicial);
    });
  }

  @override
  void dispose() {
    _api.changes.removeListener(_cambioDeCuenta);
    super.dispose();
  }

  /// Al entrar con otra cuenta, los avisos de este móvil pasan a ella.
  void _cambioDeCuenta() {
    final cuenta = _api.account?.id;
    if (cuenta == _cuenta) return;
    _cuenta = cuenta;
    if (cuenta != null) unawaited(_avisos.alEntrar());
  }

  void _abrirHistoria(String id) => _navegador.currentState?.pushNamed(storyPath(id));

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      api: _api,
      child: MaterialApp(
        title: 'Voces del Lugar',
        navigatorKey: _navegador,
        debugShowCheckedModeBanner: false,
        theme: vdlTheme(VdlColors.claro, Brightness.light),
        darkTheme: vdlTheme(VdlColors.oscuro, Brightness.dark),
        themeMode: ThemeMode.system,
        builder: (context, child) => EscalaLetra(preferencia: widget.letra, child: child!),
        onGenerateRoute: vocesRoute,
        home: !_ready
            ? const Scaffold(body: Center(child: Marca()))
            : _bienvenida
            ? BienvenidaPage(letra: widget.letra, onEmpezar: () => setState(() => _bienvenida = false))
            : AppShell(api: _api, inicial: _inicial),
      ),
    );
  }
}
