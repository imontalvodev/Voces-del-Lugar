import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/barra_inferior.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';

/// Las secciones de la app. «Revisar» solo existe para quien modera y en el
/// móvil cuelga de Cuenta.
enum Seccion {
  inicio('/', 'Inicio', LucideIcons.house),
  mapa('/mapa', 'Mapa', LucideIcons.map),
  contar('/contar/sitio', 'Contar', LucideIcons.mic),
  cuenta('/cuenta', 'Cuenta', LucideIcons.user),
  revisar('/revisar', 'Por revisar', LucideIcons.inbox);

  const Seccion(this.ruta, this.nombre, this.icono);

  final String ruta;
  final String nombre;
  final IconData icono;

  /// Las cuatro de la barra inferior, en su orden.
  static const principales = [inicio, mapa, contar, cuenta];
}

/// La sección a la que lleva una dirección escrita o pegada.
Seccion seccionDeRuta(String? ruta) {
  final camino = Uri.tryParse(ruta ?? '/')?.path ?? '/';
  if (camino == '/mapa' || camino.startsWith('/historia/')) return Seccion.mapa;
  if (camino.startsWith('/contar')) return Seccion.contar;
  if (camino == '/cuenta' || camino == '/entrar' || camino == '/crear-cuenta') return Seccion.cuenta;
  if (camino.startsWith('/revisar')) return Seccion.revisar;
  return Seccion.inicio;
}

/// El armazón de la app: barra inferior en el móvil, NavigationRail en la
/// tableta y barra superior en el escritorio. En «Contar» la barra inferior
/// desaparece para no distraer.
class Armazon extends StatelessWidget {
  const Armazon({
    super.key,
    required this.seccion,
    required this.onSeccion,
    required this.paginas,
    this.moderador = false,
  });

  final Seccion seccion;
  final ValueChanged<Seccion> onSeccion;
  final Map<Seccion, Widget> paginas;
  final bool moderador;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final orden = [...Seccion.principales, if (moderador) Seccion.revisar];
    final cuerpo = IndexedStack(
      index: orden.indexOf(seccion).clamp(0, orden.length - 1),
      children: [
        for (final s in orden)
          TickerMode(
            enabled: s == seccion,
            child: KeyedSubtree(key: ValueKey(s), child: paginas[s] ?? const SizedBox.shrink()),
          ),
      ],
    );
    return switch (tamano(context)) {
      Vdl.compacto => Scaffold(
        body: cuerpo,
        bottomNavigationBar: seccion == Seccion.contar
            ? null
            : BarraInferior(
                seleccionada: Seccion.principales.indexOf(seccion == Seccion.revisar ? Seccion.cuenta : seccion),
                onSeleccion: (i) => onSeccion(Seccion.principales[i]),
              ),
      ),
      Vdl.medio => Scaffold(
        body: Row(
          children: [
            _Rail(seccion: seccion, secciones: orden, onSeccion: onSeccion),
            Container(width: 2, color: c.tinta),
            Expanded(child: cuerpo),
          ],
        ),
      ),
      Vdl.amplio => Scaffold(
        body: Column(
          children: [
            _BarraSuperior(seccion: seccion, moderador: moderador, onSeccion: onSeccion),
            Expanded(child: cuerpo),
          ],
        ),
      ),
    };
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.seccion, required this.secciones, required this.onSeccion});

  final Seccion seccion;
  final List<Seccion> secciones;
  final ValueChanged<Seccion> onSeccion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 15, height: 1.1);
    return NavigationRail(
      backgroundColor: c.azulejo,
      labelType: NavigationRailLabelType.all,
      indicatorColor: c.anilVelo,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      selectedIndex: secciones.indexOf(seccion),
      onDestinationSelected: (i) => onSeccion(secciones[i]),
      selectedIconTheme: IconThemeData(color: c.anil, size: 26),
      unselectedIconTheme: IconThemeData(color: c.piedra, size: 26),
      selectedLabelTextStyle: letra.copyWith(color: c.anil, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: letra.copyWith(color: c.piedra, fontWeight: FontWeight.w600),
      leading: const Padding(padding: EdgeInsets.only(top: 8, bottom: 16), child: Marca(pequena: true)),
      minWidth: 96,
      destinations: [
        for (final s in secciones)
          NavigationRailDestination(
            icon: Icon(s.icono),
            label: Text(s.nombre),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
      ],
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.seccion, required this.moderador, required this.onSeccion});

  final Seccion seccion;
  final bool moderador;
  final ValueChanged<Seccion> onSeccion;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final enlaces = [Seccion.inicio, Seccion.mapa, Seccion.cuenta, if (moderador) Seccion.revisar];
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border(bottom: BorderSide(color: c.tinta, width: 2)),
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Secciones',
        child: Row(
          children: [
            PlacaPulsable(
              onPressed: () => onSeccion(Seccion.inicio),
              hunde: false,
              etiqueta: 'Voces del Lugar, inicio',
              child: const ExcludeSemantics(child: Marca()),
            ),
            const SizedBox(width: 20),
            for (final s in enlaces) _EnlaceSuperior(seccion: s, activa: s == seccion, onTap: () => onSeccion(s)),
            const Spacer(),
            BotonPlaca(
              etiqueta: 'Contar una historia',
              icono: LucideIcons.mic,
              tamano: TamanoBoton.medio,
              onPressed: () => onSeccion(Seccion.contar),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnlaceSuperior extends StatelessWidget {
  const _EnlaceSuperior({required this.seccion, required this.activa, required this.onTap});

  final Seccion seccion;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return PlacaPulsable(
      onPressed: onTap,
      hunde: false,
      seleccionado: activa,
      radio: 0,
      minimo: const Size(48, 76),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Text(
            seccion.nombre,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 17,
              color: activa ? c.anil : c.tinta,
              fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          if (activa)
            Positioned(
              left: -4,
              right: -4,
              bottom: -26,
              child: Container(height: 5, color: c.anil),
            ),
        ],
      ),
    );
  }
}

/// Cada sección guarda su propia pila: al volver a ella, sigues donde lo
/// dejaste. Avisa cuando la pila cambia para recalcular el botón Atrás.
class PilaSeccion extends StatefulWidget {
  const PilaSeccion({super.key, required this.navigatorKey, required this.raiz, this.onCambio});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget raiz;
  final VoidCallback? onCambio;

  @override
  State<PilaSeccion> createState() => _PilaSeccionState();
}

class _PilaSeccionState extends State<PilaSeccion> {
  late final _observador = _Observador(() => widget.onCambio?.call());

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      observers: [_observador],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings, builder: (_) => widget.raiz),
    );
  }
}

class _Observador extends NavigatorObserver {
  _Observador(this.cambio);

  final VoidCallback cambio;

  void _avisar() => WidgetsBinding.instance.addPostFrameCallback((_) => cambio());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _avisar();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _avisar();
}
