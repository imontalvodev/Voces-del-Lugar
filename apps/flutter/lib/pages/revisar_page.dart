import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/reproductor.dart';
import 'package:voces/ui/sello.dart';

/// «Por revisar»: la cola de la más antigua a la más nueva y la revisión de
/// cada historia antes de que llegue al mapa.
class RevisarPage extends StatefulWidget {
  const RevisarPage({super.key, required this.api});

  final VocesApi api;

  @override
  State<RevisarPage> createState() => _RevisarPageState();
}

class _RevisarPageState extends State<RevisarPage> {
  List<StoryPin> _cola = [];
  bool _cargando = true;
  bool _sinConexion = false;
  String? _elegida;
  bool _ocupado = false;
  int _ticket = 0;

  /// En el móvil, la revisión se abre encima de la cola.
  Route<void>? _detalle;

  @override
  void initState() {
    super.initState();
    widget.api.changes.addListener(_recargar);
    _recargar();
  }

  @override
  void dispose() {
    widget.api.changes.removeListener(_recargar);
    super.dispose();
  }

  Future<void> _recargar() async {
    if (!mounted || !(widget.api.account?.canModerate ?? false)) return;
    final ticket = ++_ticket;
    setState(() {
      _cargando = _cola.isEmpty;
      _sinConexion = false;
    });
    try {
      final cola = await widget.api.reviewQueue();
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _cola = cola;
        if (_elegida != null && cola.every((h) => h.id != _elegida)) _elegida = null;
      });
    } catch (_) {
      if (mounted && ticket == _ticket) setState(() => _sinConexion = true);
    } finally {
      if (mounted && ticket == _ticket) setState(() => _cargando = false);
    }
  }

  Future<void> _decidir(StoryPin h, {required bool publicar}) async {
    final seguro = publicar
        ? await confirmar(
            context,
            titulo: '¿Publicar en el mapa?',
            mensaje:
                'Cualquiera podrá ver y escuchar «${h.title}» en ${h.placeName}. Podrás retirarla más adelante si hace falta.',
            si: 'Sí, publicar en el mapa',
          )
        : await confirmar(
            context,
            titulo: '¿Rechazar esta historia?',
            mensaje: 'No llegará al mapa. Quien la subió lo verá en su cuenta.',
            si: 'Sí, rechazar',
            peligro: true,
          );
    if (!seguro || !mounted) return;
    setState(() => _ocupado = true);
    try {
      if (publicar) {
        await widget.api.publish(h.id);
      } else {
        await widget.api.reject(h.id);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _cola = _cola.where((x) => x.id != h.id).toList();
        _elegida = null;
      });
      // Decidida, se vuelve a la cola.
      final detalle = _detalle;
      if (detalle != null && detalle.isActive) Navigator.of(context).removeRoute(detalle);
      _detalle = null;
      mostrarNotificacion(context, publicar ? 'Publicada. Ya está en el mapa.' : 'Rechazada. No llegará al mapa.');
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.message, error: true);
    } catch (_) {
      if (mounted) mostrarNotificacion(context, 'No hay conexión. Revisa el wifi o los datos.', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _abrir(StoryPin h) {
    if (tamano(context) == Vdl.amplio) {
      setState(() => _elegida = h.id);
      return;
    }
    Navigator.push(
      context,
      _detalle = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/revisar/historia'),
        builder: (context) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: MargenPagina(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EnlaceDiscreto(
                      etiqueta: 'Volver a la cola',
                      icono: LucideIcons.arrowLeft,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 6),
                    StatefulBuilder(
                      builder: (context, _) => _Revision(
                        historia: h,
                        ocupado: _ocupado,
                        onPublicar: () => _decidir(h, publicar: true),
                        onRechazar: () => _decidir(h, publicar: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.api.account?.canModerate ?? false)) {
      return Scaffold(
        body: SafeArea(
          child: MargenPagina(
            ancho: 640,
            child: Vacio(
              titulo: 'Esta parte es solo para moderadores',
              texto: 'Si crees que deberías tener acceso, escribe a quien coordina Voces del Lugar en tu zona.',
              icono: LucideIcons.lock,
              accion: BotonPlaca(etiqueta: 'Ir al inicio', onPressed: () => irA(Seccion.inicio)),
            ),
          ),
        ),
      );
    }
    final amplio = tamano(context) == Vdl.amplio;
    final elegida = _cola.where((h) => h.id == _elegida).firstOrNull ?? (amplio ? _cola.firstOrNull : null);
    final cola = _ColaRevision(
      cola: _cola,
      cargando: _cargando,
      sinConexion: _sinConexion,
      elegida: amplio ? elegida?.id : null,
      onReintentar: _recargar,
      onAbrir: _abrir,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: MargenPagina(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Navigator.canPop(context))
                    EnlaceDiscreto(
                      etiqueta: 'Volver',
                      icono: LucideIcons.arrowLeft,
                      onPressed: () => Navigator.pop(context),
                    ),
                  if (amplio)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 420, child: cola),
                        const SizedBox(width: 40),
                        Expanded(
                          child: elegida == null
                              ? const SizedBox.shrink()
                              : _Revision(
                                  key: ValueKey(elegida.id),
                                  historia: elegida,
                                  ocupado: _ocupado,
                                  onPublicar: () => _decidir(elegida, publicar: true),
                                  onRechazar: () => _decidir(elegida, publicar: false),
                                ),
                        ),
                      ],
                    )
                  else
                    cola,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColaRevision extends StatelessWidget {
  const _ColaRevision({
    required this.cola,
    required this.cargando,
    required this.sinConexion,
    required this.elegida,
    required this.onReintentar,
    required this.onAbrir,
  });

  final List<StoryPin> cola;
  final bool cargando;
  final bool sinConexion;
  final String? elegida;
  final VoidCallback onReintentar;
  final ValueChanged<StoryPin> onAbrir;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Cola por revisar',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloPantalla('Por revisar'),
          const Entradilla('De la más antigua a la más nueva.'),
          const SizedBox(height: 10),
          if (cargando)
            const Cargando(texto: 'Cargando la cola…', bloques: 2)
          else if (sinConexion)
            AvisoSinConexion(onRetry: onReintentar)
          else if (cola.isEmpty)
            const Vacio(
              titulo: 'No hay historias por revisar',
              texto: 'Cuando alguien deje una, aparecerá aquí.',
              icono: LucideIcons.inbox,
            )
          else
            for (final (i, h) in cola.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PlacaPulsable(
                  onPressed: () => onAbrir(h),
                  hunde: false,
                  radio: 2,
                  seleccionado: h.id == elegida,
                  color: h.id == elegida ? c.anilVelo : c.azulejo,
                  borde: h.id == elegida ? c.anil : c.tinta,
                  alineacion: Alignment.centerLeft,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i + 1}º${h.number == null ? '' : ' · ${numeroFicha(h.number!)}'}',
                              style: registro.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: c.piedra),
                            ),
                          ),
                          if (h.createdAt != null)
                            Text(
                              fechaCorta(h.createdAt!),
                              style: registro.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: c.piedra),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(h.title, style: letra.titleMedium!.copyWith(fontSize: 19, height: 1.25)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          h.placeName,
                          categoryLabel(h.category),
                          h.hasAudio ? ['Audio', ?duracionCorta(h.audioSeconds)].join(' ') : 'Texto',
                        ].join(' · '),
                        style: letra.bodySmall!.copyWith(color: c.piedra),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Una historia en revisión con todo lo que hace falta para decidir.
class _Revision extends StatelessWidget {
  const _Revision({
    super.key,
    required this.historia,
    required this.ocupado,
    required this.onPublicar,
    required this.onRechazar,
  });

  final StoryPin historia;
  final bool ocupado;
  final VoidCallback onPublicar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final h = historia;
    final amplio = tamano(context) == Vdl.amplio;
    final cuerpo = (h.body ?? '').trim();
    final filas = <(String, Widget)>[
      ('Lugar', Text(h.placeName)),
      ('Tipo', EtiquetaTipo(h.category, color: c.tinta)),
      ('Época', Text(decadeLabel(h.decade) ?? 'Sin indicar')),
      ('Contada por', Text(contadaPor(h.narratorName, h.narratorRelation, deceased: h.narratorDeceased))),
      ('Subida por', Text(h.authorName?.trim().isNotEmpty == true ? h.authorName! : '—')),
      if (h.createdAt != null) ('Enviada', Text(fechaCorta(h.createdAt!))),
      ('Permiso', const Text('Confirmado por quien la subió')),
      ('Licencia', Text(licenseLabel(h.license))),
    ];
    final botones = [
      BotonPlaca(
        etiqueta: 'Publicar en el mapa',
        icono: LucideIcons.check,
        expandir: !amplio,
        cargando: ocupado ? 'Guardando…' : null,
        onPressed: onPublicar,
      ),
      BotonPlaca(
        etiqueta: 'Rechazar',
        variante: VarianteBoton.peligroBorde,
        expandir: !amplio,
        onPressed: ocupado ? null : onRechazar,
      ),
    ];
    return Semantics(
      container: true,
      label: 'Revisando ${h.title}',
      explicitChildNodes: true,
      child: TarjetaConPestana(
        pestana: h.number == null ? 'Nº ----' : numeroFicha(h.number!),
        padding: EdgeInsets.all(amplio ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  const Sello(EstadoSello.enRevision),
                  if (h.narratorDeceased) const Sello(EstadoSello.permisoFamilia),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TituloPantalla(h.title),
            const SizedBox(height: 14),
            for (final (dato, valor) in filas)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.filete, width: 1.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        dato,
                        style: registro.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: c.piedra),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: registro.copyWith(fontSize: 17, color: c.tinta),
                        child: valor,
                      ),
                    ),
                  ],
                ),
              ),
            if (h.hasAudio) ...[const SizedBox(height: 18), Reproductor(url: h.mediaUrls.first, titulo: h.title)],
            if (cuerpo.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final (i, p) in cuerpo.split(RegExp(r'\n\s*\n')).indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: Text(p.trim(), style: letra.bodyLarge),
                ),
            ],
            const SizedBox(height: 24),
            if (amplio)
              Wrap(spacing: 10, runSpacing: 10, children: botones)
            else
              Column(children: [botones[0], const SizedBox(height: 10), botones[1]]),
          ],
        ),
      ),
    );
  }
}
