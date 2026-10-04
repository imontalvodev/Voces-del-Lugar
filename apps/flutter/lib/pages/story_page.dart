import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/audio.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/story_card.dart';
import 'package:voces/ui/tokens.dart';
import 'package:voces/ui/voice_terrain.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.story});

  final StoryPin story;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _energy = ValueNotifier<double>(0.35);
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
    _energy.dispose();
    super.dispose();
  }

  /// La tarjeta pudo quedarse vieja: se trae la ficha como está ahora.
  Future<void> _fetch() async {
    try {
      final fresh = await _api!.story(widget.story.id);
      if (mounted) setState(() => _story = fresh);
    } catch (_) {
      // Se queda lo que ya se ve.
    }
  }

  Future<void> _run(Future<StoryPin> Function(VocesApi api) action, String done) async {
    final api = _api;
    if (api == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await action(api);
      if (!mounted) return;
      setState(() => _story = updated);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No hay conexión con el archivo.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (!await confirmReject(context, _story)) return;
    await _run((api) => api.reject(_story.id), 'Rechazada. No llegará al mapa.');
  }

  Future<void> _unpublish() async {
    final sure = await confirm(
      context,
      title: '¿La quitas del mapa?',
      message: 'Vuelve a revisión. Nadie más la verá hasta que alguien la publique otra vez.',
      action: 'Quitarla del mapa',
    );
    if (!sure) return;
    await _run((api) => api.unpublish(_story.id), 'Retirada del mapa. Queda en revisión.');
  }

  Future<void> _edit() async {
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

  List<Widget> _actions() {
    final api = _api;
    final account = api?.account;
    if (api == null || account == null) return const [];
    final story = _story;
    return [
      if (account.canModerate && story.pending) ...[
        LampButton(
          label: 'Publicar en el mapa',
          icon: LucideIcons.check,
          busy: _busy,
          onPressed: () => _run((api) => api.publish(story.id), 'Publicada. Ya está en el mapa.'),
        ),
        GhostButton(label: 'Rechazar', icon: LucideIcons.x, onPressed: _busy ? null : _reject),
      ],
      if (account.canModerate && story.published)
        GhostButton(label: 'Quitar del mapa', icon: LucideIcons.eyeOff, onPressed: _busy ? null : _unpublish),
      if (story.status == 'rejected' && account.canModerate)
        GhostButton(
          label: 'Publicar de todos modos',
          icon: LucideIcons.check,
          onPressed: _busy ? null : () => _run((api) => api.publish(story.id), 'Publicada. Ya está en el mapa.'),
        ),
      if (api.owns(story) && story.pending)
        GhostButton(label: 'Corregir', icon: LucideIcons.pencil, onPressed: _busy ? null : _edit),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final actions = _actions();
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 600 ? 46.0 : 72.0;
    final body = story.body?.trim() ?? '';
    final fade = !MediaQuery.disableAnimationsOf(context);
    Widget reveal(Widget child, int order) {
      if (!fade) return child;
      return child
          .animate(delay: (160 + order * 70).ms)
          .fadeIn(duration: 520.ms, curve: Motion.out)
          .moveY(begin: 14, end: 0, duration: 520.ms, curve: Motion.out);
    }

    return Scaffold(
      backgroundColor: Palette.night,
      body: Sky(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: width < 600 ? 280 : 360,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.white, Colors.transparent],
                          stops: [0, 0.62, 1],
                        ).createShader(rect),
                        child: VoiceTerrain(
                          rows: 26,
                          horizon: 0.3,
                          energy: _energy,
                          selectedId: story.id,
                          beacons: [TerrainBeacon(id: story.id, x: 0.0, z: 0.55, label: story.placeName)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GlassIconButton(
                            icon: LucideIcons.arrowLeft,
                            tooltip: 'Volver',
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(width < 600 ? 22 : 32, 0, width < 600 ? 22 : 32, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        reveal(
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.mapPin, size: 17, color: Palette.lamp),
                                  const SizedBox(width: 6),
                                  Text(
                                    story.placeName,
                                    style: text(size: 16, weight: FontWeight.w600, color: Palette.lamp),
                                  ),
                                ],
                              ),
                              Text(coordinateLabel(story.point), style: text(size: 13.5, color: Palette.haze)),
                            ],
                          ),
                          0,
                        ),
                        const SizedBox(height: 16),
                        reveal(Text(story.title, style: display(titleSize)), 1),
                        const SizedBox(height: 16),
                        reveal(Text(narratorLine(story), style: text(size: 18, color: Palette.bone.withValues(alpha: 0.86))), 2),
                        if ((story.narratorRelation ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          reveal(Text(story.narratorRelation!.trim(), style: text(size: 15, color: Palette.haze)), 2),
                        ],
                        if (story.mediaUrls.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          reveal(StoryPlayer(url: story.mediaUrls.first, seed: story.id, energy: _energy), 3),
                        ],
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 36),
                          reveal(SelectableText(body, style: text(size: 19, height: 1.72, color: Palette.bone.withValues(alpha: 0.94))), 4),
                        ],
                        const SizedBox(height: 44),
                        Container(height: 1, color: Palette.glassEdge),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(status: story.status),
                            Text(categoryLabel(story.category), style: text(size: 14, color: Palette.haze)),
                            Text('Licencia ${licenseLabel(story.license)}', style: text(size: 14, color: Palette.haze)),
                          ],
                        ),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Wrap(spacing: 12, runSpacing: 12, children: actions),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pregunta antes de algo que cambia lo que ve todo el mundo.
Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => _GlassDialog(
      title: title,
      body: Text(message, style: text(size: 15.5, color: Palette.haze)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        LampButton(label: action, onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  return answer ?? false;
}

Future<bool> confirmReject(BuildContext context, StoryPin story) {
  return confirm(
    context,
    title: '¿Rechazar «${story.title}»?',
    message: 'No llegará al mapa. Quien la dejó la verá como rechazada en su cuenta.',
    action: 'Rechazar',
  );
}

typedef StoryEdit = ({String title, String body, String narratorName, String narratorRelation});

/// Formulario para corregir una historia que sigue en revisión.
Future<StoryEdit?> editStory(BuildContext context, StoryPin story) {
  return showDialog<StoryEdit>(context: context, builder: (_) => _StoryEditor(story: story));
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
    return _GlassDialog(
      title: 'Corregir la historia',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 180,
            style: text(size: 17),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            decoration: InputDecoration(labelText: 'Título', errorText: _titleError),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 10,
            style: text(size: 16, height: 1.55),
            onChanged: (_) {
              if (_bodyError != null) setState(() => _bodyError = null);
            },
            decoration: InputDecoration(labelText: 'Qué se contaba', alignLabelWithHint: true, errorText: _bodyError),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _narrator,
            maxLength: 160,
            style: text(size: 16),
            decoration: const InputDecoration(labelText: 'Nombre de quien la cuenta'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _relation,
            maxLength: 80,
            style: text(size: 16),
            decoration: const InputDecoration(labelText: 'Qué es para ti'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        LampButton(label: 'Guardar la corrección', icon: LucideIcons.check, onPressed: _save),
      ],
    );
  }
}

class _GlassDialog extends StatelessWidget {
  const _GlassDialog({required this.title, required this.body, required this.actions});

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Glass(
          radius: 28,
          tint: Palette.glassStrong,
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(34)),
                const SizedBox(height: 16),
                body,
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
