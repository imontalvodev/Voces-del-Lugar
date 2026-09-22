import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';

const _ink = Color(0xFF1B2420);
const _field = Color(0xFFD7E0D4);
const _paper = Color(0xFFF3F6F1);
const _seal = Color(0xFF9E3A32);
const _moss = Color(0xFF2F5D45);

void main() {
  runApp(const VocesApp());
}

class VocesApp extends StatelessWidget {
  const VocesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.sourceSans3TextTheme().apply(bodyColor: _ink, displayColor: _ink);
    return MaterialApp(
      title: 'Voces del Lugar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _field,
        colorScheme: ColorScheme.fromSeed(seedColor: _moss, primary: _moss, surface: _paper),
        textTheme: text.copyWith(
          headlineMedium: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w500, color: _ink, height: 1.05),
          titleLarge: GoogleFonts.newsreader(fontSize: 26, fontWeight: FontWeight.w500, color: _ink),
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _api = VocesApi();
  final _map = MapController();
  List<StoryPin> _stories = [];
  StoryPin? _open;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _api.restore().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _reload() async {
    final bounds = _map.camera.visibleBounds;
    try {
      final stories = await _api.mapStories(bounds.west, bounds.south, bounds.east, bounds.north);
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _compose() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ComposePage(api: _api, point: _map.camera.center)),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: const LatLng(40.416, -3.703),
              initialZoom: 13,
              onMapReady: () {
                _ready = true;
                _reload();
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _reload();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.vocesdellugar.voces',
              ),
              MarkerLayer(
                markers: [
                  for (final story in _stories)
                    Marker(
                      point: story.point,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() => _open = story),
                        child: const Icon(Icons.place, color: _seal, size: 40),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Voces del Lugar', style: Theme.of(context).textTheme.headlineMedium),
                ),
                _AccountButton(api: _api, onChanged: () => setState(() {})),
              ],
            ),
          ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              top: 72,
              child: Material(color: _paper, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
            ),
          if (_open != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 88,
              child: _StoryCard(story: _open!, onClose: () => setState(() => _open = null)),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FilledButton(
              onPressed: !_ready
                  ? null
                  : () {
                      if (_api.account == null) {
                        _openAccount();
                      } else {
                        _compose();
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: _seal, foregroundColor: _paper, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_api.account == null ? 'Entrar para dejar una historia' : 'Dejar una historia en el centro del mapa'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccount() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AccountPage(api: _api)));
    if (mounted) setState(() {});
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.api, required this.onChanged});
  final VocesApi api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final account = api.account;
    if (account == null) {
      return TextButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AccountPage(api: api)));
          onChanged();
        },
        child: const Text('Entrar'),
      );
    }
    return TextButton(
      onPressed: () async {
        await api.logout();
        onChanged();
      },
      child: Text(account.displayName),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onClose});
  final StoryPin story;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paper,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(story.title, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            Text(story.placeName),
            if (story.narratorName != null) Text('Lo cuenta ${story.narratorName}'),
            if (story.body != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(story.body!)),
            const SizedBox(height: 8),
            Text(story.license),
            if (story.mediaUrls.isNotEmpty) Text('Audio: ${story.mediaUrls.first}'),
          ],
        ),
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api});
  final VocesApi api;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.api.register(_email.text.trim(), _password.text, _name.text.trim());
      } else {
        await widget.api.login(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registering ? 'Crear cuenta' : 'Entrar')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'La primera cuenta de una base vacía queda como administradora y puede publicar.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_registering) ...[
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Cómo te llamas')),
            const SizedBox(height: 12),
          ],
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: _seal))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_registering ? 'Crear cuenta' : 'Entrar')),
          TextButton(
            onPressed: () => setState(() => _registering = !_registering),
            child: Text(_registering ? 'Ya tengo cuenta' : 'No tengo cuenta'),
          ),
        ],
      ),
    );
  }
}

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
  String? _error;
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
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'webm', 'aac']);
    if (file != null) setState(() => _audio = file);
  }

  Future<void> _submit() async {
    if (!_consent) {
      setState(() => _error = 'Hace falta el consentimiento de quien narra, o de su familia.');
      return;
    }
    if (_body.text.trim().isEmpty && _audio == null) {
      setState(() => _error = 'Escribe la historia o adjunta un audio.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
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
      if (_audio != null) {
        final bytes = await _audio!.readAsBytes();
        await widget.api.uploadAudio(story.id, _audio!.name, bytes);
      }
      if (_publish && widget.api.account!.canModerate) {
        await widget.api.publish(story.id);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    return Scaffold(
      appBar: AppBar(title: const Text('Dejar una historia')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('El punto es el centro del mapa: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}.'),
          const SizedBox(height: 16),
          TextField(controller: _place, decoration: const InputDecoration(labelText: 'Nombre del lugar')),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
          const SizedBox(height: 12),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'La historia'), minLines: 4, maxLines: 8),
          const SizedBox(height: 12),
          TextField(controller: _narrator, decoration: const InputDecoration(labelText: 'Quién la cuenta')),
          const SizedBox(height: 12),
          TextField(controller: _relation, decoration: const InputDecoration(labelText: 'Parentesco o relación')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quien narra ya ha fallecido'),
            subtitle: const Text('El permiso lo da la familia.'),
            value: _deceased,
            onChanged: (value) => setState(() => _deceased = value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hay permiso para publicar esta historia con la licencia elegida.'),
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
          ),
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
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _pickAudio, child: Text(_audio == null ? 'Adjuntar un audio' : _audio!.name)),
          if (widget.api.account?.canModerate == true)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar ahora'),
              value: _publish,
              onChanged: (value) => setState(() => _publish = value),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: _seal))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
