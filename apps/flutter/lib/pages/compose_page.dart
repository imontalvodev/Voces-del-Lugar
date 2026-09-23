import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/map_page.dart' show LampPin;
import 'package:voces/story_format.dart';
import 'package:voces/ui/audio.dart';
import 'package:voces/ui/dusk_tiles.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/tokens.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key, required this.api, required this.point});

  final VocesApi api;
  final LatLng point;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

enum _Step { place, story, narrator, consent, done }

class _ComposePageState extends State<ComposePage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _narrator = TextEditingController();
  final _relation = TextEditingController();
  final _place = TextEditingController();
  bool _deceased = false;
  bool _consent = false;
  bool _publish = true;
  bool _writing = false;
  String _license = 'CC-BY-SA-4.0';
  RecordedClip? _clip;
  PlatformFile? _file;
  String? _placeError;
  String? _titleError;
  String? _storyError;
  String? _consentError;
  String? _formError;
  bool _busy = false;
  bool _published = false;
  _Step _step = _Step.place;
  bool _forward = true;

  static const _asks = [_Step.place, _Step.story, _Step.narrator, _Step.consent];

  @override
  void dispose() {
    for (final c in [_title, _body, _narrator, _relation, _place]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasAudio => _clip != null || _file != null;

  Future<void> _pickAudio() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'webm', 'aac']);
    if (file != null) {
      setState(() {
        _file = file;
        _clip = null;
        _storyError = null;
      });
    }
  }

  bool _check(_Step step) {
    switch (step) {
      case _Step.place:
        final error = _place.text.trim().isEmpty ? 'Escribe cómo llama la gente a este sitio.' : null;
        setState(() => _placeError = error);
        return error == null;
      case _Step.story:
        final title = _title.text.trim().isEmpty ? 'Ponle un título, aunque sea corto.' : null;
        final story = _body.text.trim().isEmpty && !_hasAudio ? 'Graba la historia o escríbela. Con una de las dos basta.' : null;
        setState(() {
          _titleError = title;
          _storyError = story;
        });
        return title == null && story == null;
      case _Step.consent:
        final error = _consent ? null : 'Marca la casilla: sin permiso no se puede guardar.';
        setState(() => _consentError = error);
        return error == null;
      case _Step.narrator:
      case _Step.done:
        return true;
    }
  }

  void _go(_Step step) {
    setState(() {
      _forward = step.index > _step.index;
      _step = step;
    });
  }

  void _next() {
    if (!_check(_step)) return;
    if (_step == _Step.consent) {
      _submit();
      return;
    }
    _go(_Step.values[_step.index + 1]);
  }

  Future<void> _submit() async {
    for (final step in [_Step.place, _Step.story, _Step.consent]) {
      if (!_check(step)) {
        _go(step);
        return;
      }
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final story = await widget.api.createStory(
        title: _title.text.trim(),
        body: _body.text.trim(),
        narratorName: _narrator.text.trim(),
        relation: _relation.text.trim(),
        deceased: _deceased,
        license: _license,
        placeName: _place.text.trim(),
        point: widget.point,
      );
      if (_clip != null) {
        await widget.api.uploadAudio(story.id, _clip!.filename, _clip!.bytes);
      } else if (_file != null) {
        await widget.api.uploadAudio(story.id, _file!.name, await _file!.readAsBytes());
      }
      final publish = _publish && widget.api.account!.canModerate;
      if (publish) await widget.api.publish(story.id);
      if (!mounted) return;
      _published = publish;
      _go(_Step.done);
    } on ApiException catch (error) {
      setState(() => _formError = error.message);
    } catch (_) {
      setState(() => _formError = 'No se pudo guardar: no hay conexión con el archivo. Tu historia sigue aquí, vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final done = _step == _Step.done;
    return Scaffold(
      backgroundColor: Palette.night,
      body: Sky(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: done ? LucideIcons.check : LucideIcons.x,
                      tooltip: done ? 'Terminar' : 'Salir sin guardar',
                      onPressed: () => Navigator.pop(context, done),
                    ),
                    const SizedBox(width: 16),
                    if (!done)
                      Expanded(
                        child: _Progress(step: _step.index, total: _asks.length, onJump: _jump),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageTransitionSwitcher(
                  duration: Motion.of(context, const Duration(milliseconds: 460)),
                  reverse: !_forward,
                  transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                    animation: primary,
                    secondaryAnimation: secondary,
                    transitionType: SharedAxisTransitionType.horizontal,
                    fillColor: Colors.transparent,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(narrow ? 22 : 32, narrow ? 28 : 48, narrow ? 22 : 32, 32),
                          children: [_page()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!done)
                Padding(
                  padding: EdgeInsets.fromLTRB(narrow ? 22 : 32, 8, narrow ? 22 : 32, 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        if (_formError != null) ...[Notice(message: _formError!), const SizedBox(height: 12)],
                        Row(
                          children: [
                            if (_step != _Step.place)
                              GhostButton(label: 'Atrás', icon: LucideIcons.arrowLeft, onPressed: () => _go(_Step.values[_step.index - 1])),
                            if (_step != _Step.place) const SizedBox(width: 12),
                            Expanded(
                              child: LampButton(
                                label: _step == _Step.consent ? (_busy ? 'Guardando la historia' : 'Guardar la historia') : 'Seguir',
                                icon: _step == _Step.consent ? LucideIcons.circleCheck : LucideIcons.arrowRight,
                                busy: _busy,
                                expand: true,
                                onPressed: _next,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _jump(int index) {
    final target = _asks[index];
    if (target.index <= _step.index || _check(_step)) _go(target);
  }

  Widget _question(String title, String help) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: display(44, height: 1.0)),
        const SizedBox(height: 12),
        Text(help, style: text(size: 16, color: Palette.haze)),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _page() {
    switch (_step) {
      case _Step.place:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _question('¿Cómo se llama este sitio?', 'El nombre que usa la gente de allí: la plaza, el lavadero, la casa de la esquina.'),
            _MiniMap(point: widget.point),
            const SizedBox(height: 20),
            TextField(
              controller: _place,
              autofocus: true,
              style: text(size: 18),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _next(),
              onChanged: (_) {
                if (_placeError != null) setState(() => _placeError = null);
              },
              decoration: InputDecoration(labelText: 'Nombre del sitio', errorText: _placeError),
            ),
          ],
        );
      case _Step.story:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _question('Cuéntala', 'Lo más fácil es grabar a quien la cuenta, tal cual. Si prefieres, escríbela.'),
            TextField(
              controller: _title,
              style: text(size: 18),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              decoration: InputDecoration(labelText: 'Título', hintText: 'La noche que se heló la fuente', errorText: _titleError),
            ),
            const SizedBox(height: 24),
            _ModeSwitch(writing: _writing, onChanged: (value) => setState(() => _writing = value)),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.settle),
              child: _writing
                  ? TextField(
                      key: const ValueKey('write'),
                      controller: _body,
                      minLines: 7,
                      maxLines: 14,
                      style: text(size: 17, height: 1.6),
                      onChanged: (_) {
                        if (_storyError != null) setState(() => _storyError = null);
                      },
                      decoration: const InputDecoration(labelText: 'Qué se contaba', alignLabelWithHint: true),
                    )
                  : Column(
                      key: const ValueKey('record'),
                      children: [
                        Center(
                          child: VoiceRecorder(
                            clip: _clip,
                            onChanged: (clip) => setState(() {
                              _clip = clip;
                              if (clip != null) {
                                _file = null;
                                _storyError = null;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _pickAudio,
                            icon: const Icon(LucideIcons.paperclip, size: 18),
                            label: Text(_file == null ? 'O adjunta una grabación que ya tengas' : 'Adjunto: ${_file!.name}'),
                          ),
                        ),
                      ],
                    ),
            ),
            if (_storyError != null) ...[const SizedBox(height: 12), Text(_storyError!, style: text(size: 14, color: Palette.alarm))],
          ],
        );
      case _Step.narrator:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _question('¿Quién la cuenta?', 'Su nombre queda junto a la historia. Si no quiere que aparezca, déjalo en blanco.'),
            TextField(
              controller: _narrator,
              style: text(size: 18),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nombre de quien la cuenta', hintText: 'Carmen Ruiz'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relation,
              style: text(size: 18),
              decoration: const InputDecoration(labelText: 'Qué es para ti', hintText: 'Mi abuela, un vecino…'),
            ),
            const SizedBox(height: 20),
            _Toggle(
              title: 'Ya ha fallecido',
              subtitle: 'Entonces el permiso para publicarla lo da su familia.',
              value: _deceased,
              onChanged: (value) => setState(() => _deceased = value),
            ),
          ],
        );
      case _Step.consent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _question('¿Hay permiso?', 'La historia es de quien la cuenta. Elige cómo se puede volver a usar.'),
            for (final (value, title, detail) in const [
              (
                'CC-BY-SA-4.0',
                'Compartir igual',
                'Cualquiera puede usarla citando la fuente, y lo que haga con ella se comparte igual. Recomendada.',
              ),
              ('CC-BY-4.0', 'Citando la fuente', 'Cualquiera puede usarla, también en obras cerradas, siempre que diga de dónde sale.'),
              ('CC0-1.0', 'Dominio público', 'Sin condiciones. Cualquiera puede usarla sin citar.'),
            ]) ...[
              _LicenseOption(
                title: title,
                code: licenseLabel(value),
                detail: detail,
                selected: _license == value,
                onTap: () => setState(() => _license = value),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            _Toggle(
              title: 'Tengo permiso de quien la cuenta, o de su familia, para publicarla así.',
              value: _consent,
              checkbox: true,
              error: _consentError,
              onChanged: (value) => setState(() {
                _consent = value;
                _consentError = null;
              }),
            ),
            if (widget.api.account?.canModerate == true) ...[
              const SizedBox(height: 10),
              _Toggle(
                title: 'Publicarla ya',
                subtitle: 'Puedes moderar, así que no hace falta que la revise nadie más.',
                value: _publish,
                onChanged: (value) => setState(() => _publish = value),
              ),
            ],
          ],
        );
      case _Step.done:
        return _Done(
          published: _published,
          title: _title.text.trim(),
          place: _place.text.trim(),
          onClose: () => Navigator.pop(context, true),
        );
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total, required this.onJump});

  final int step;
  final int total;
  final ValueChanged<int> onJump;

  static const _names = ['Sitio', 'Historia', 'Quién', 'Permiso'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: i == step,
              label: 'Paso ${i + 1} de $total: ${_names[i]}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onJump(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Container(color: Palette.glassEdge),
                              AnimatedFractionallySizedBox(
                                duration: Motion.of(context, Motion.slow),
                                curve: Motion.out,
                                widthFactor: i <= step ? 1 : 0,
                                child: Container(decoration: const BoxDecoration(gradient: Palette.lampGlow)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _names[i],
                        style: text(size: 12.5, weight: FontWeight.w600, color: i == step ? Palette.lamp : Palette.haze),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.point});

  final LatLng point;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 16.5, backgroundColor: Palette.deep),
                children: [
                  duskTiles(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 96,
                        height: 96,
                        child: LampPin(label: 'Sitio marcado', selected: true, onTap: () {}),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Glass(
                radius: 999,
                tint: Palette.glassStrong,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(coordinateLabel(point), style: text(size: 12.5, color: Palette.bone)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.writing, required this.onChanged});

  final bool writing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, IconData icon, bool value) {
      final selected = writing == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 48,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: selected ? Palette.deep : Palette.bone),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: Motion.quick,
                      style: text(size: 15, weight: FontWeight.w600, color: selected ? Palette.deep : Palette.bone),
                      child: Text(label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Glass(
      radius: 999,
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.of(context, Motion.settle),
              curve: Motion.emphasized,
              alignment: writing ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(gradient: Palette.lampGlow, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
          ),
          Row(children: [option('Grabar', LucideIcons.mic, false), option('Escribir', LucideIcons.penLine, true)]),
        ],
      ),
    );
  }
}

class _LicenseOption extends StatelessWidget {
  const _LicenseOption({required this.title, required this.code, required this.detail, required this.selected, required this.onTap});

  final String title;
  final String code;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        lift: false,
        semanticLabel: '$title, $code',
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.settle),
          curve: Motion.emphasized,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: selected ? Palette.lamp.withValues(alpha: 0.12) : Palette.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Palette.lamp : Palette.glassEdge, width: selected ? 1.6 : 1),
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.settle),
                  margin: const EdgeInsets.only(top: 3),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? Palette.lamp : Palette.haze, width: selected ? 6 : 1.6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: text(size: 16.5, weight: FontWeight.w700)),
                          Text(code, style: text(size: 13, color: Palette.haze)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(detail, style: text(size: 14, color: Palette.haze)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.title, required this.value, required this.onChanged, this.subtitle, this.checkbox = false, this.error});

  final String title;
  final String? subtitle;
  final bool value;
  final bool checkbox;
  final String? error;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: MergeSemantics(
        child: Row(
          children: [
            if (checkbox) ...[Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)), const SizedBox(width: 6)],
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text(size: 15.5, weight: FontWeight.w600)),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: text(size: 13.5, color: Palette.haze))],
                    if (error != null) ...[const SizedBox(height: 4), Text(error!, style: text(size: 13.5, color: Palette.alarm))],
                  ],
                ),
              ),
            ),
            if (!checkbox) Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.published, required this.title, required this.place, required this.onClose});

  final bool published;
  final String title;
  final String place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    Widget lamp = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Palette.lampGlow,
        boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: 0.7), blurRadius: 80, spreadRadius: 10)],
      ),
      child: const Icon(LucideIcons.lightbulb, size: 52, color: Palette.deep),
    );
    if (!still) {
      lamp = lamp
          .animate()
          .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 900.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 300.ms)
          .then()
          .shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: 0.4));
    }
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(child: lamp),
        const SizedBox(height: 40),
        Text(
          published ? 'Ya hay una luz más en el mapa.' : 'Guardada. Falta que alguien la revise.',
          textAlign: TextAlign.center,
          style: display(44),
        ),
        const SizedBox(height: 14),
        Text(
          published
              ? '«$title» ya se puede escuchar en $place.'
              : '«$title» aparecerá en $place cuando la publique quien modera el archivo. Puedes verla en tu cuenta.',
          textAlign: TextAlign.center,
          style: text(size: 16.5, color: Palette.haze),
        ),
        const SizedBox(height: 32),
        LampButton(label: 'Volver al mapa', icon: LucideIcons.map, onPressed: onClose),
      ],
    );
  }
}
