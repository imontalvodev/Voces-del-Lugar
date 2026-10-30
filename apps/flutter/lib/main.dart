import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/shell.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/blur_gate.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/tokens.dart';

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

  @override
  void initState() {
    super.initState();
    _api.restore().whenComplete(() {
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
        builder: (context, child) => EscalaLetra(
          preferencia: widget.letra,
          child: BlurGate(child: child!),
        ),
        onGenerateRoute: vocesRoute,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: _ready
              ? AppShell(api: _api)
              : Scaffold(
                  backgroundColor: Palette.night,
                  body: Sky(
                    child: Center(child: Text('Voces del Lugar', style: display(40))),
                  ),
                ),
        ),
      ),
    );
  }
}
