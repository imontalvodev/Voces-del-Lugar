import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key, required this.api, required this.point});

  final VocesApi api;
  final LatLng point;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _narrator = TextEditingController();
  final _relation = TextEditingController();
  final _place = TextEditingController();
  bool _deceased = false;
  bool _consent = false;
  bool _publish = true;
  String _license = 'CC-BY-SA-4.0';
  PlatformFile? _audio;
  String? _placeError;
  String? _titleError;
  String? _storyError;
  String? _consentError;
  String? _formError;
  bool _busy = false;
  int _step = 0;

  static const _steps = ['Lugar', 'Historia', 'Quién cuenta', 'Permiso'];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _narrator.dispose();
    _relation.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'webm', 'aac'],
    );
    if (file != null) {
      setState(() {
        _audio = file;
        _storyError = null;
      });
    }
  }

  bool _stepOk(int step) {
    if (step == 0) {
      final place = _place.text.trim().isEmpty ? 'Escribe cómo se llama este sitio.' : null;
      setState(() => _placeError = place);
      return place == null;
    }
    if (step == 1) {
      final title = _title.text.trim().isEmpty ? 'Ponle un título.' : null;
      final story = _body.text.trim().isEmpty && _audio == null ? 'Escribe la historia o adjunta la grabación.' : null;
      setState(() {
        _titleError = title;
        _storyError = story;
      });
      return title == null && story == null;
    }
    if (step == 3) {
      final consent = _consent ? null : 'Marca el permiso para poder guardarla.';
      setState(() => _consentError = consent);
      return consent == null;
    }
    return true;
  }

  void _next() {
    if (!_stepOk(_step)) return;
    if (_step < _steps.length - 1) {
      setState(() => _step += 1);
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    if (!_stepOk(0) || !_stepOk(1) || !_stepOk(3)) return;
    setState(() => _busy = true);
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
      if (_audio != null) {
        final bytes = await _audio!.readAsBytes();
        await widget.api.uploadAudio(story.id, _audio!.name, bytes);
      }
      if (_publish && widget.api.account!.canModerate) {
        await widget.api.publish(story.id);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VocesColors.desk,
      appBar: AppBar(title: const Text('Dejar una historia')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              Container(
                color: VocesColors.paper,
                padding: const EdgeInsets.fromLTRB(28, 28, 36, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 16, height: 16, decoration: const BoxDecoration(color: VocesColors.desk, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${coordinateLabel(widget.point)} · punto marcado', style: vocesMono())),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 22),
                              child: _Tab(
                                label: _steps[i],
                                active: _step == i,
                                onTap: () {
                                  if (i <= _step || _stepOk(_step)) setState(() => _step = i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: VocesColors.paperLine),
                    const SizedBox(height: 24),
                    if (_step == 0) ...[
                      TextField(
                        controller: _place,
                        decoration: InputDecoration(labelText: 'Nombre del lugar', errorText: _placeError),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_placeError != null) setState(() => _placeError = null);
                        },
                      ),
                    ] else if (_step == 1) ...[
                      TextField(
                        controller: _title,
                        decoration: InputDecoration(labelText: 'Título', errorText: _titleError),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_titleError != null) setState(() => _titleError = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _body,
                        decoration: InputDecoration(labelText: 'Qué se contaba', errorText: _storyError, alignLabelWithHint: true),
                        minLines: 5,
                        maxLines: 10,
                        onChanged: (_) {
                          if (_storyError != null) setState(() => _storyError = null);
                        },
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(onPressed: _pickAudio, child: Text(_audio == null ? 'Adjuntar la grabación' : _audio!.name)),
                          Text('o escribe el texto arriba, con uno de los dos basta', style: vocesSans(size: 12.5, color: VocesColors.muted)),
                        ],
                      ),
                    ] else if (_step == 2) ...[
                      TextField(controller: _narrator, decoration: const InputDecoration(labelText: 'Nombre'), textInputAction: TextInputAction.next),
                      const SizedBox(height: 12),
                      TextField(controller: _relation, decoration: const InputDecoration(labelText: 'Parentesco o relación')),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Quien narra ya ha fallecido'),
                        subtitle: const Text('El permiso lo da la familia.'),
                        value: _deceased,
                        onChanged: (value) => setState(() => _deceased = value),
                      ),
                    ] else ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hay permiso para publicar esta historia con la licencia elegida.'),
                        value: _consent,
                        onChanged: (value) => setState(() {
                          _consent = value ?? false;
                          _consentError = null;
                        }),
                      ),
                      if (_consentError != null) Text(_consentError!, style: vocesSans(size: 13, color: VocesColors.crimson)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _license,
                        decoration: const InputDecoration(labelText: 'Licencia'),
                        items: const [
                          DropdownMenuItem(value: 'CC-BY-SA-4.0', child: Text('CC BY-SA 4.0')),
                          DropdownMenuItem(value: 'CC-BY-4.0', child: Text('CC BY 4.0')),
                          DropdownMenuItem(value: 'CC0-1.0', child: Text('CC0')),
                        ],
                        onChanged: (value) => setState(() => _license = value ?? _license),
                      ),
                      if (widget.api.account?.canModerate == true)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Publicar ahora'),
                          value: _publish,
                          onChanged: (value) => setState(() => _publish = value),
                        ),
                    ],
                    if (_formError != null) ...[
                      const SizedBox(height: 12),
                      Text(_formError!, style: vocesSans(size: 14, color: VocesColors.crimson)),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _step == 0 ? null : () => setState(() => _step -= 1),
                          child: const Text('Anterior'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy ? null : _next,
                          child: Text(_busy ? 'Guardando' : (_step == _steps.length - 1 ? 'Guardar la historia' : 'Guardar y seguir')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? VocesColors.marigold : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: vocesSans(size: 14, weight: FontWeight.w700, color: active ? VocesColors.ink : VocesColors.muted)),
      ),
    );
  }
}
