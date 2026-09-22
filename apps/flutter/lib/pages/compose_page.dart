import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
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

  bool _valid() {
    final place = _place.text.trim().isEmpty ? 'Escribe cómo se llama este sitio.' : null;
    final title = _title.text.trim().isEmpty ? 'Ponle un título.' : null;
    final story = _body.text.trim().isEmpty && _audio == null ? 'Escribe la historia o adjunta la grabación.' : null;
    final consent = _consent ? null : 'Marca el permiso para poder guardarla.';
    setState(() {
      _placeError = place;
      _titleError = title;
      _storyError = story;
      _consentError = consent;
      _formError = null;
    });
    return place == null && title == null && story == null && consent == null;
  }

  Future<void> _submit() async {
    if (!_valid()) return;
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
    final point = widget.point;
    return Scaffold(
      appBar: AppBar(title: const Text('Dejar una historia')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 48),
            children: [
              Text('El lugar', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Marcado en el mapa: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}.'),
              const SizedBox(height: 12),
              TextField(
                controller: _place,
                decoration: InputDecoration(labelText: 'Nombre del lugar', errorText: _placeError),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_placeError != null) setState(() => _placeError = null);
                },
              ),
              const SizedBox(height: 28),
              Text('La historia', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(labelText: 'Título', errorText: _titleError),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                decoration: InputDecoration(labelText: 'Qué se contaba', errorText: _storyError, alignLabelWithHint: true),
                minLines: 5,
                maxLines: 10,
                onChanged: (_) {
                  if (_storyError != null) setState(() => _storyError = null);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: _pickAudio, child: Text(_audio == null ? 'Adjuntar la grabación' : _audio!.name)),
              ),
              const SizedBox(height: 28),
              Text('Quién la cuenta', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Text('Permiso', style: Theme.of(context).textTheme.titleLarge),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hay permiso para publicar esta historia con la licencia elegida.'),
                value: _consent,
                onChanged: (value) => setState(() {
                  _consent = value ?? false;
                  _consentError = null;
                }),
              ),
              if (_consentError != null) Text(_consentError!, style: const TextStyle(color: VocesColors.seal)),
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
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(_formError!, style: const TextStyle(color: VocesColors.seal)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Guardando' : 'Guardar la historia')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
