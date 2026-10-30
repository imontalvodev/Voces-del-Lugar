import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/navegacion.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/campos.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/placa_mapa.dart';
import 'package:voces/ui/reproductor.dart';
import 'package:voces/ui/sello.dart';
import 'package:voces/ui/teselas.dart';

/// Ficha de una historia: datos a máquina, reproductor, lo que cuenta, la
/// licencia en lenguaje llano y el enlace. Quien la subió la corrige y quien
/// modera la publica, la rechaza o la retira.
class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.story, this.escuchar = false, this.conTeselas = true});

  final StoryPin story;

  /// Llega desde «Escuchar»: el audio empieza a sonar.
  final bool escuchar;
  final bool conTeselas;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late StoryPin _story = widget.story;
  VocesApi? _api;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = ApiScope.maybeOf(context);
    if (api != null && _api == null) {
      _api = api;
      api.changes.addListener(_onChanged);
      _fetch();
    }
  }

  /// Si cambia la sesión (por ejemplo, caduca), las acciones se recalculan.
  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _api?.changes.removeListener(_onChanged);
    super.dispose();
  }

  /// La ficha pudo quedarse vieja: se trae como está ahora.
  Future<void> _fetch() async {
    try {
      final fresh = await _api!.story(widget.story.id);
      if (mounted) setState(() => _story = fresh);
    } catch (_) {
      // Se queda lo que ya se ve.
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: enlacePublico(_story.id)));
    if (mounted) mostrarNotificacion(context, 'Enlace copiado. Ya puedes pegarlo donde quieras.');
  }

  Future<void> _run(
    Future<StoryPin> Function(VocesApi api) action,
    String hecho, {
    String? deshacer,
    Future<StoryPin> Function(VocesApi api)? alDeshacer,
  }) async {
    final api = _api;
    if (api == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action(api);
      if (!mounted) return;
      setState(() => _story = updated);
      HapticFeedback.mediumImpact();
      mostrarNotificacion(
        context,
        hecho,
        accion: deshacer,
        onAccion: alDeshacer == null ? null : () => _run(alDeshacer, 'Hecho. Vuelve a estar como antes.'),
      );
    } on ApiException catch (error) {
      if (mounted) mostrarNotificacion(context, error.message, error: true);
    } catch (_) {
      if (mounted) mostrarNotificacion(context, 'No hay conexión. Revisa el wifi o los datos.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publicar() async {
    if (!await confirmarPublicar(context, _story)) return;
    await _run((api) => api.publish(_story.id), 'Publicada. Ya está en el mapa.');
  }

  Future<void> _rechazar() async {
    if (!await confirmReject(context, _story)) return;
    await _run((api) => api.reject(_story.id), 'Rechazada. No llegará al mapa.');
  }

  Future<void> _retirar() async {
    if (!await confirmarRetirar(context, _story)) return;
    final id = _story.id;
    await _run(
      (api) => api.unpublish(id),
      'Retirada. Ya no está en el mapa.',
      deshacer: 'Deshacer',
      alDeshacer: (api) => api.publish(id),
    );
  }

  Future<void> _corregir() async {
    final patch = await editStory(context, _story);
    if (patch == null) return;
    String? changed(String value, String? before) => value == (before ?? '').trim() ? null : value;
    final title = changed(patch.title, _story.title);
    final body = changed(patch.body, _story.body);
    final narrator = changed(patch.narratorName, _story.narratorName);
    final relation = changed(patch.narratorRelation, _story.narratorRelation);
    if (title == null && body == null && narrator == null && relation == null) return;
    await _run(
      (api) => api.updateStory(_story.id, title: title, body: body, narratorName: narrator, narratorRelation: relation),
      'Corrección guardada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final amplio = tamano(context) == Vdl.amplio;
    final ficha = _Ficha(
      story: _story,
      escuchar: widget.escuchar,
      onCopiar: _copiar,
      onCorregir: (_api?.owns(_story) ?? false) && _story.pending && !_busy ? _corregir : null,
    );
    final lateral = [
      _DondePaso(story: _story, conTeselas: widget.conTeselas),
      if (_api?.account?.canModerate ?? false)
        _Moderacion(story: _story, busy: _busy, onPublicar: _publicar, onRechazar: _rechazar, onRetirar: _retirar),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: MargenPagina(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EnlaceDiscreto(
                  etiqueta: 'Volver',
                  icono: Theme.of(context).platform == TargetPlatform.iOS
                      ? LucideIcons.chevronLeft
                      : LucideIcons.arrowLeft,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: 6),
                if (amplio)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ficha),
                      const SizedBox(width: 40),
                      SizedBox(
                        width: 360,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              for (final (i, w) in lateral.indexed) ...[if (i > 0) const SizedBox(height: 20), w],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  ficha,
                  for (final w in lateral) ...[const SizedBox(height: 24), w],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.story, required this.escuchar, required this.onCopiar, required this.onCorregir});

  final StoryPin story;
  final bool escuchar;
  final VoidCallback onCopiar;
  final VoidCallback? onCorregir;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final amplio = tamano(context) == Vdl.amplio;
    final cuerpo = (story.body ?? '').trim();
    final parrafos = cuerpo.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final licencia = licenciaLlana(story.license);
    final estado = story.published ? null : EstadoSello.deStatus(story.status);
    final filas = <(String, Widget)>[
      ('Lugar', Text(story.placeName)),
      ('Tipo', EtiquetaTipo(story.category, color: c.tinta)),
      if (decadeLabel(story.decade) case final epoca?) ('Época', Text(epoca)),
      ('Contada por', Text(contadaPor(story.narratorName, story.narratorRelation, deceased: story.narratorDeceased))),
      if (story.authorName case final autor? when autor.trim().isNotEmpty) ('Recogida por', Text(autor)),
    ];
    return Padding(
      padding: EdgeInsets.only(top: story.number == null ? 0 : 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: amplio ? const EdgeInsets.fromLTRB(32, 32, 32, 28) : const EdgeInsets.fromLTRB(18, 24, 18, 20),
            decoration: BoxDecoration(
              color: c.azulejo,
              border: Border.all(color: c.tinta, width: 1.5),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: c.sombra, offset: const Offset(4, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (story.narratorDeceased || estado != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (estado != null) Sello(estado, grande: true),
                        if (story.narratorDeceased) const Sello(EstadoSello.permisoFamilia, grande: true),
                      ],
                    ),
                  ),
                if (story.narratorDeceased || estado != null) const SizedBox(height: 10),
                TituloPantalla(story.title),
                const SizedBox(height: 16),
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
                          width: 130,
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
                if (story.hasAudio) ...[
                  const SizedBox(height: 20),
                  Reproductor(url: story.mediaUrls.first, titulo: story.title, empezar: escuchar),
                ],
                if (parrafos.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  if (story.hasAudio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Semantics(
                        header: true,
                        child: Text('Lo que cuenta', style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, p) in parrafos.indexed)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                              child: Text(p, style: letra.bodyLarge),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.ficha,
                    border: Border.all(color: c.tinta, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: licenseLabel(story.license), style: registro.copyWith(fontSize: 17)),
                            TextSpan(text: ' · ${licencia.nombre}'),
                          ],
                        ),
                        style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(licencia.detalle, style: letra.bodySmall!.copyWith(color: c.piedra)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BotonPlaca(
                      etiqueta: 'Copiar enlace',
                      icono: LucideIcons.link2,
                      expandir: !amplio,
                      onPressed: onCopiar,
                    ),
                    if (onCorregir != null)
                      BotonPlaca(
                        etiqueta: 'Corregir',
                        icono: LucideIcons.penLine,
                        variante: VarianteBoton.secundario,
                        expandir: !amplio,
                        onPressed: onCorregir,
                      ),
                    SizedBox(
                      width: amplio ? null : double.infinity,
                      child: Text(
                        enlacePublico(story.id).replaceFirst(RegExp(r'^https?://'), ''),
                        textAlign: amplio ? TextAlign.start : TextAlign.center,
                        style: registro.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: c.piedra),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (story.number != null)
            Positioned(
              top: -15,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                decoration: BoxDecoration(
                  color: c.azulejo,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  border: Border(
                    top: BorderSide(color: c.tinta, width: 1.5),
                    left: BorderSide(color: c.tinta, width: 1.5),
                    right: BorderSide(color: c.tinta, width: 1.5),
                  ),
                ),
                child: Text(
                  numeroFicha(story.number!),
                  style: registro.copyWith(fontSize: 15, height: 1.6, color: c.tinta),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DondePaso extends StatelessWidget {
  const _DondePaso({required this.story, required this.conTeselas});

  final StoryPin story;
  final bool conTeselas;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final amplio = tamano(context) == Vdl.amplio;
    final medida = PlacaLugar.medida(story.placeName, MediaQuery.textScalerOf(context));
    return Semantics(
      container: true,
      label: 'Dónde pasó',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Dónde pasó',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: amplio ? 300 : 190,
            decoration: BoxDecoration(
              border: Border.all(color: c.tinta, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRect(
              child: ExcludeSemantics(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: story.point,
                    initialZoom: 16,
                    backgroundColor: c.cal,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    if (conTeselas) teselasVdl(context),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: story.point,
                          width: medida.width,
                          height: medida.height,
                          alignment: Alignment.topCenter,
                          child: PlacaLugar(nombre: story.placeName, recuento: 1, elegida: true, onTap: () {}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: EnlaceDiscreto(
              etiqueta: 'Ver en el mapa',
              onPressed: () => irA(Seccion.mapa, lugarId: story.placeId, punto: story.point),
            ),
          ),
        ],
      ),
    );
  }
}

class _Moderacion extends StatelessWidget {
  const _Moderacion({
    required this.story,
    required this.busy,
    required this.onPublicar,
    required this.onRechazar,
    required this.onRetirar,
  });

  final StoryPin story;
  final bool busy;
  final VoidCallback onPublicar;
  final VoidCallback onRechazar;
  final VoidCallback onRetirar;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final acciones = <Widget>[
      if (story.pending) ...[
        BotonPlaca(
          etiqueta: 'Publicar en el mapa',
          icono: LucideIcons.check,
          tamano: TamanoBoton.medio,
          expandir: true,
          cargando: busy ? 'Guardando…' : null,
          onPressed: onPublicar,
        ),
        BotonPlaca(
          etiqueta: 'Rechazar',
          variante: VarianteBoton.peligroBorde,
          tamano: TamanoBoton.medio,
          expandir: true,
          onPressed: busy ? null : onRechazar,
        ),
      ],
      if (story.published)
        BotonPlaca(
          etiqueta: 'Retirar del mapa',
          variante: VarianteBoton.peligroBorde,
          tamano: TamanoBoton.medio,
          expandir: true,
          onPressed: busy ? null : onRetirar,
        ),
    ];
    if (acciones.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      painter: BordeSello(color: c.filete, discontinuo: true, grosor: 1.5, radio: 2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Herramientas de moderación',
              style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Solo lo ves porque moderas el archivo.', style: letra.bodySmall!.copyWith(color: c.piedra)),
            const SizedBox(height: 10),
            for (final (i, a) in acciones.indexed) ...[if (i > 0) const SizedBox(height: 10), a],
          ],
        ),
      ),
    );
  }
}

/// «Esta historia no está»: el enlace no lleva a ninguna.
class HistoriaNoEsta extends StatelessWidget {
  const HistoriaNoEsta({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final amplio = tamano(context) == Vdl.amplio;
    void ir(Seccion s) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      irA(s);
    }

    final botones = [
      BotonPlaca(
        etiqueta: 'Abrir el mapa',
        icono: LucideIcons.map,
        expandir: !amplio,
        onPressed: () => ir(Seccion.mapa),
      ),
      BotonPlaca(
        etiqueta: 'Ir al inicio',
        variante: VarianteBoton.secundario,
        expandir: !amplio,
        onPressed: () => ir(Seccion.inicio),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: MargenPagina(
            ancho: 720,
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    painter: BordeSello(color: c.tinta, discontinuo: true, grosor: 1.5, radio: 2),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(1.5),
                      color: c.azulejo,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
                      child: Column(
                        children: [
                          Icon(LucideIcons.searchX, size: 44, color: c.piedra),
                          const SizedBox(height: 8),
                          const TituloPantalla('Esta historia no está'),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              'Puede que el enlace esté mal copiado o que la hayan retirado del mapa.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.piedra),
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (amplio)
                            Wrap(spacing: 10, alignment: WrapAlignment.center, children: botones)
                          else
                            Column(children: [botones[0], const SizedBox(height: 10), botones[1]]),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -15,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.azulejo,
                        border: Border(
                          top: BorderSide(color: c.tinta, width: 1.5),
                          left: BorderSide(color: c.tinta, width: 1.5),
                          right: BorderSide(color: c.tinta, width: 1.5),
                        ),
                      ),
                      child: Text('Nº ----', style: registro.copyWith(fontSize: 15, height: 1.6, color: c.tinta)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «¿Publicar en el mapa?»
Future<bool> confirmarPublicar(BuildContext context, StoryPin story) {
  return confirmar(
    context,
    titulo: '¿Publicar en el mapa?',
    mensaje: 'Cualquiera podrá ver y escuchar «${story.title}» en ${story.placeName}.',
    si: 'Sí, publicar en el mapa',
  );
}

/// «¿Rechazar esta historia?»
Future<bool> confirmReject(BuildContext context, StoryPin story) {
  return confirmar(
    context,
    titulo: '¿Rechazar esta historia?',
    mensaje: '«${story.title}» no llegará al mapa. Quien la dejó la verá como rechazada en su cuenta.',
    si: 'Sí, rechazar',
    peligro: true,
  );
}

/// «¿Retirar del mapa?»
Future<bool> confirmarRetirar(BuildContext context, StoryPin story) {
  return confirmar(
    context,
    titulo: '¿Retirar del mapa?',
    mensaje:
        '«${story.title}» dejará de verse en el mapa y su enlace dirá que no está. Quien la subió lo verá en su cuenta.',
    si: 'Sí, retirar del mapa',
    peligro: true,
  );
}

typedef StoryEdit = ({String title, String body, String narratorName, String narratorRelation});

/// Formulario para corregir una historia que sigue en revisión.
Future<StoryEdit?> editStory(BuildContext context, StoryPin story) {
  return showDialog<StoryEdit>(
    context: context,
    barrierColor: VdlColors.of(context).scrim,
    animationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
    builder: (_) => _StoryEditor(story: story),
  );
}

class _StoryEditor extends StatefulWidget {
  const _StoryEditor({required this.story});

  final StoryPin story;

  @override
  State<_StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<_StoryEditor> {
  late final _title = TextEditingController(text: widget.story.title);
  late final _body = TextEditingController(text: widget.story.body ?? '');
  late final _narrator = TextEditingController(text: widget.story.narratorName ?? '');
  late final _relation = TextEditingController(text: widget.story.narratorRelation ?? '');
  String? _titleError;
  String? _bodyError;

  @override
  void dispose() {
    for (final c in [_title, _body, _narrator, _relation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final emptyStory = _body.text.trim().isEmpty && widget.story.mediaUrls.isEmpty;
    setState(() {
      _titleError = title.isEmpty ? 'Ponle un título, aunque sea corto.' : null;
      _bodyError = emptyStory ? 'Sin grabación, hace falta el texto para poder publicarla.' : null;
    });
    if (_titleError != null || _bodyError != null) return;
    Navigator.pop<StoryEdit>(context, (
      title: title,
      body: _body.text.trim(),
      narratorName: _narrator.text.trim(),
      narratorRelation: _relation.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DialogoVdl(
      titulo: 'Corregir la historia',
      acciones: [
        BotonPlaca(etiqueta: 'Guardar la corrección', icono: LucideIcons.check, expandir: true, onPressed: _save),
        BotonPlaca(
          etiqueta: 'Cancelar',
          variante: VarianteBoton.secundario,
          expandir: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CampoTexto(
            etiqueta: 'Título',
            controller: _title,
            maximo: 180,
            error: _titleError,
            onChanged: (_) => _titleError == null ? null : setState(() => _titleError = null),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Lo que cuenta',
            controller: _body,
            lineas: 5,
            error: _bodyError,
            opcional: widget.story.hasAudio,
            onChanged: (_) => _bodyError == null ? null : setState(() => _bodyError = null),
          ),
          const SizedBox(height: 16),
          CampoTexto(etiqueta: 'Nombre de quien la cuenta', controller: _narrator, maximo: 160, opcional: true),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Parentesco',
            ayuda: 'Por ejemplo: «abuela», «vecino».',
            controller: _relation,
            maximo: 80,
            opcional: true,
          ),
        ],
      ),
    );
  }
}

/// El enlace público de una historia: en web, el de la dirección por la que
/// se entró; en el móvil, el del sitio web del archivo.
String enlacePublico(String id) {
  const base = String.fromEnvironment('WEB_BASE', defaultValue: 'https://vocesdellugar.org');
  return kIsWeb ? storyLink(id, Uri.base) : '$base${storyPath(id)}';
}
