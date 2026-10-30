import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/pages/entrar_page.dart';
import 'package:voces/pages/revisar_page.dart';
import 'package:voces/pages/story_page.dart' show editStory;
import 'package:voces/story_format.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/sello.dart';

/// Cuenta: entrar o crear cuenta y, con sesión, el rol, el ajuste de letra y
/// «Lo que has dejado» con su estado.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.onChanged, required this.onLeaveStory});

  final VocesApi api;
  final VoidCallback onChanged;
  final VoidCallback onLeaveStory;

  @override
  State<AccountPage> createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  List<StoryPin> _mias = [];
  int _porRevisar = 0;
  bool _cargando = true;
  bool _sinConexion = false;
  int _ticket = 0;
  String? _cuentaVista;

  @override
  void initState() {
    super.initState();
    widget.api.changes.addListener(_cambio);
    reload();
  }

  @override
  void dispose() {
    widget.api.changes.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() {
    if (!mounted) return;
    // Si cambia la cuenta, lo de la anterior no se enseña ni un instante.
    if (_cuentaVista != widget.api.account?.id) {
      setState(() {
        _mias = [];
        _porRevisar = 0;
        _cargando = true;
      });
    }
    reload();
  }

  Future<void> reload() async {
    final cuenta = widget.api.account;
    if (!mounted) return;
    final ticket = ++_ticket;
    _cuentaVista = cuenta?.id;
    if (cuenta == null) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = _mias.isEmpty;
      _sinConexion = false;
    });
    try {
      final mias = await widget.api.mine();
      if (!mounted || ticket != _ticket) return;
      setState(() => _mias = mias);
    } catch (_) {
      if (mounted && ticket == _ticket) setState(() => _sinConexion = true);
    } finally {
      if (mounted && ticket == _ticket) setState(() => _cargando = false);
    }
    if (cuenta.canModerate) {
      try {
        final cola = await widget.api.reviewQueue();
        if (mounted && ticket == _ticket) setState(() => _porRevisar = cola.length);
      } catch (_) {
        // La cola es un extra: si falla, lo tuyo se sigue viendo.
      }
    }
  }

  Future<void> _corregir(StoryPin h) async {
    final cambio = await editStory(context, h);
    if (cambio == null || !mounted) return;
    try {
      await widget.api.updateStory(
        h.id,
        title: cambio.title,
        body: cambio.body,
        narratorName: cambio.narratorName,
        narratorRelation: cambio.narratorRelation,
      );
      if (mounted) mostrarNotificacion(context, 'Corrección guardada.');
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.message, error: true);
    } catch (_) {
      if (mounted) mostrarNotificacion(context, 'No hay conexión. Revisa el wifi o los datos.', error: true);
    }
  }

  Future<void> _salir() async {
    await widget.api.logout();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = widget.api.account;
    if (cuenta == null) {
      return EntrarPage(
        key: ValueKey(widget.api.sesionCaducada),
        api: widget.api,
        sesionCaducada: widget.api.sesionCaducada,
        onHecho: () {
          widget.onChanged();
          reload();
        },
      );
    }
    final amplio = tamano(context) == Vdl.amplio;
    final tarjeta = _TarjetaCuenta(
      cuenta: cuenta,
      porRevisar: _porRevisar,
      onRevisar: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RevisarPage(api: widget.api))),
      onSalir: _salir,
    );
    final ajustes = kIsWeb ? null : const _Ajustes();
    final lista = _LoQueHasDejado(
      historias: _mias,
      cargando: _cargando,
      sinConexion: _sinConexion,
      onReintentar: reload,
      onContar: widget.onLeaveStory,
      onCorregir: _corregir,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: reload,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: MargenPagina(
              child: amplio
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              tarjeta,
                              if (ajustes != null) ...[const SizedBox(height: 24), ajustes],
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(child: lista),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tarjeta,
                        const SizedBox(height: 28),
                        lista,
                        if (ajustes != null) ...[const SizedBox(height: 28), ajustes],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaCuenta extends StatelessWidget {
  const _TarjetaCuenta({
    required this.cuenta,
    required this.porRevisar,
    required this.onRevisar,
    required this.onSalir,
  });

  final Account cuenta;
  final int porRevisar;
  final VoidCallback onRevisar;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Tu cuenta',
      explicitChildNodes: true,
      child: TarjetaConPestana(
        pestana: 'Cuenta',
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(cuenta.displayName, style: letra.headlineMedium!.copyWith(fontSize: 26)),
            ),
            const SizedBox(height: 2),
            Text(cuenta.email, style: letra.bodySmall!.copyWith(color: c.piedra)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.filete, width: 1.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      'Rol',
                      style: registro.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: c.piedra),
                    ),
                  ),
                  Expanded(
                    child: Text(rolCorto(cuenta.role), style: registro.copyWith(fontSize: 17, color: c.tinta)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(roleLabel(cuenta.role), style: letra.bodySmall!.copyWith(color: c.piedra)),
            if (cuenta.canModerate) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.anilVelo,
                  border: Border.all(color: c.anil, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Por revisar: ',
                        children: [
                          TextSpan(text: '$porRevisar', style: registro.copyWith(fontSize: 18)),
                          TextSpan(text: porRevisar == 1 ? ' historia' : ' historias'),
                        ],
                      ),
                      style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    BotonPlaca(
                      etiqueta: 'Ir a revisar',
                      icono: LucideIcons.inbox,
                      tamano: TamanoBoton.medio,
                      expandir: true,
                      onPressed: onRevisar,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: EnlaceDiscreto(etiqueta: 'Salir de la cuenta', icono: LucideIcons.logOut, onPressed: onSalir),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ajustes: el tamaño de letra propio, que se suma al del móvil.
class _Ajustes extends StatelessWidget {
  const _Ajustes();

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final preferencia = PreferenciaLetra.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border.all(color: c.tinta, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Ajustes'),
          const SizedBox(height: 12),
          Text('Tamaño de letra', style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: c.tinta, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (tamano, muestra)) in [
                    (TamanoLetra.normal, 16.0),
                    (TamanoLetra.grande, 19.0),
                    (TamanoLetra.muyGrande, 22.0),
                  ].indexed) ...[
                    if (i > 0) Container(width: 2, color: c.tinta),
                    Expanded(
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: preferencia.value == tamano,
                        child: PlacaPulsable(
                          onPressed: () => preferencia.elegir(tamano),
                          etiqueta: tamano.nombre,
                          hunde: false,
                          radio: 0,
                          seleccionado: preferencia.value == tamano,
                          color: preferencia.value == tamano ? c.anil : c.azulejo,
                          minimo: const Size(48, 64),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Aa',
                                  textScaler: TextScaler.noScaling,
                                  style: letra.bodyMedium!.copyWith(
                                    fontSize: muestra,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: preferencia.value == tamano ? c.sobreAnil : c.tinta,
                                  ),
                                ),
                                Text(
                                  tamano.nombre,
                                  textAlign: TextAlign.center,
                                  style: letra.bodySmall!.copyWith(
                                    fontSize: 14,
                                    height: 1.2,
                                    color: preferencia.value == tamano ? c.sobreAnil : c.tinta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Se suma al tamaño que tengas en el móvil.',
            style: letra.bodySmall!.copyWith(fontSize: 15, color: c.piedra),
          ),
        ],
      ),
    );
  }
}

class _LoQueHasDejado extends StatelessWidget {
  const _LoQueHasDejado({
    required this.historias,
    required this.cargando,
    required this.sinConexion,
    required this.onReintentar,
    required this.onContar,
    required this.onCorregir,
  });

  final List<StoryPin> historias;
  final bool cargando;
  final bool sinConexion;
  final VoidCallback onReintentar;
  final VoidCallback onContar;
  final ValueChanged<StoryPin> onCorregir;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Semantics(
      container: true,
      label: 'Lo que has dejado',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Lo que has dejado'),
          const SizedBox(height: 4),
          Text(
            'Mientras una historia está en revisión, puedes corregirla.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 17, color: c.piedra),
          ),
          const SizedBox(height: 6),
          if (cargando)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Cargando(texto: 'Cargando lo que has dejado…', bloques: 2),
            )
          else if (sinConexion)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AvisoSinConexion(onRetry: onReintentar),
            )
          else if (historias.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Vacio(
                titulo: 'Todavía no has dejado ninguna historia',
                texto: 'Graba a alguien de tu familia o a un vecino. Es tan fácil como mandar un audio.',
                icono: LucideIcons.mic,
                accion: BotonPlaca(etiqueta: 'Contar una historia', icono: LucideIcons.mic, onPressed: onContar),
              ),
            )
          else
            for (final h in historias)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FichaHistoria.de(h, sello: EstadoSello.deStatus(h.status), onTap: () => openStory(context, h)),
                    if (h.pending) ...[
                      const SizedBox(height: 8),
                      BotonPlaca(
                        etiqueta: 'Corregir',
                        icono: LucideIcons.penLine,
                        variante: VarianteBoton.secundario,
                        tamano: TamanoBoton.medio,
                        onPressed: () => onCorregir(h),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
