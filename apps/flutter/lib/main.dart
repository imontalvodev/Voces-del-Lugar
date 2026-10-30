import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/pages/bienvenida_page.dart';
import 'package:voces/shell.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/pagina.dart';

Future<void> main() async {
  usePathUrlStrategy(); // /historia/<id> en vez de /#/historia/<id>
  WidgetsFlutterBinding.ensureInitialized();
  final letra = await PreferenciaLetra.cargar();
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
  var _ready = false;

  /// La sección de la dirección por la que se entra (en web, la barra).
  final _inicial = seccionDeRuta(WidgetsBinding.instance.platformDispatcher.defaultRouteName);

  /// Primer arranque: antes de nada, la bienvenida con el tamaño de letra.
  var _bienvenida = false;

  @override
  void initState() {
    super.initState();
    Future.wait([_api.restore(), bienvenidaVista().then((vista) => _bienvenida = !vista)]).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      api: _api,
      child: MaterialApp(
        title: 'Voces del Lugar',
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
