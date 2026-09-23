import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';

const _home = LatLng(40.416, -3.703);

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.api, required this.onLeaveStory});

  final VocesApi api;
  final void Function(LatLng point) onLeaveStory;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final _map = MapController();
  final _query = TextEditingController();
  List<StoryPin> _stories = [];
  String? _selectedId;
  String? _placeId;
  String? _narrator;
  String? _category;
  LatLng? _draft;
  String? _error;
  bool _ready = false;
  bool _awaitingTap = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void beginPlacing() {
    setState(() {
      _awaitingTap = true;
      _placeId = null;
      _selectedId = null;
    });
  }

  List<StoryPin> get _visible {
    final q = _query.text.trim().toLowerCase();
    return [
      for (final story in _stories)
        if (_matches(story, q)) story,
    ];
  }

  bool _matches(StoryPin story, String q) {
    if (_placeId != null && story.placeId != _placeId) return false;
    if (_narrator != null && (story.narratorName ?? '') != _narrator) return false;
    if (_category != null && story.category != _category) return false;
    if (q.isEmpty) return true;
    final blob = '${story.title} ${story.placeName} ${story.narratorName ?? ''} ${story.body ?? ''}'.toLowerCase();
    return blob.contains(q);
  }

  Future<void> reload() async {
    if (!_ready) return;
    final bounds = _map.camera.visibleBounds;
    try {
      final stories = await widget.api.mapStories(bounds.west, bounds.south, bounds.east, bounds.north);
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _error = null;
        if (_selectedId != null && stories.every((story) => story.id != _selectedId)) _selectedId = null;
        if (_placeId != null && stories.every((story) => story.placeId != _placeId)) _placeId = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _select(StoryPin story) {
    setState(() {
      _selectedId = story.id;
      _placeId = story.placeId;
      _draft = null;
      _awaitingTap = false;
    });
    if (_ready) _map.move(story.point, 16);
  }

  void _drop(LatLng point) {
    setState(() {
      _draft = point;
      _awaitingTap = false;
      _selectedId = null;
      _placeId = null;
    });
  }

  void _clearPlace() => setState(() {
        _placeId = null;
        _selectedId = null;
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final map = _MapCanvas(
      controller: _map,
      stories: _visible,
      selectedId: _selectedId,
      draft: _draft,
      onReady: () {
        _ready = true;
        reload();
      },
      onMoveEnd: reload,
      onSelect: _select,
      onDrop: _drop,
      onZoom: (delta) {
        final camera = _map.camera;
        _map.move(camera.center, (camera.zoom + delta).clamp(3, 18));
      },
      onReset: () => _map.move(_home, 13),
    );
    final rail = _StoryRail(
      stories: _stories,
      visible: _visible,
      selectedId: _selectedId,
      placeId: _placeId,
      narrator: _narrator,
      category: _category,
      query: _query,
      draft: _draft,
      awaitingTap: _awaitingTap,
      error: _error,
      onQuery: () => setState(() {}),
      onNarrator: (value) => setState(() => _narrator = value),
      onCategory: (value) => setState(() => _category = value),
      onSelect: _select,
      onClearPlace: _clearPlace,
      onRead: (story) => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage(story: story))),
      onWrite: _draft == null ? null : () => widget.onLeaveStory(_draft!),
    );
    if (!wide) {
      return Column(children: [Expanded(flex: 3, child: map), Expanded(flex: 2, child: rail)]);
    }
    return Row(
      children: [
        SizedBox(width: 380, child: rail),
        const VerticalDivider(width: 1, color: Color(0x33F2ECD8)),
        Expanded(child: map),
      ],
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.controller,
    required this.stories,
    required this.selectedId,
    required this.draft,
    required this.onReady,
    required this.onMoveEnd,
    required this.onSelect,
    required this.onDrop,
    required this.onZoom,
    required this.onReset,
  });

  final MapController controller;
  final List<StoryPin> stories;
  final String? selectedId;
  final LatLng? draft;
  final VoidCallback onReady;
  final VoidCallback onMoveEnd;
  final ValueChanged<StoryPin> onSelect;
  final ValueChanged<LatLng> onDrop;
  final ValueChanged<double> onZoom;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _home,
            initialZoom: 13,
            onMapReady: onReady,
            onTap: (_, point) => onDrop(point),
            onMapEvent: (event) {
              if (event is MapEventMoveEnd) onMoveEnd();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.vocesdellugar.voces',
              tileBuilder: (context, tileWidget, _) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.mode(VocesColors.mapGround, BlendMode.color),
                  child: tileWidget,
                );
              },
            ),
            MarkerLayer(
              markers: [
                for (final story in stories)
                  Marker(
                    point: story.point,
                    width: story.id == selectedId ? 32 : 26,
                    height: story.id == selectedId ? 32 : 26,
                    child: _Pin(selected: story.id == selectedId, label: story.placeName, onPressed: () => onSelect(story)),
                  ),
                if (draft != null)
                  Marker(
                    point: draft!,
                    width: 22,
                    height: 22,
                    child: const _DraftPin(),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          left: 16,
          bottom: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xD9123449)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '© colaboradores de OpenStreetMap',
                style: TextStyle(color: VocesColors.mutedOnDesk, fontSize: 11),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            children: [
              _MapButton(label: 'Acercar', icon: Icons.add, onPressed: () => onZoom(1)),
              const SizedBox(height: 8),
              _MapButton(label: 'Alejar', icon: Icons.remove, onPressed: () => onZoom(-1)),
              const SizedBox(height: 8),
              _MapButton(label: 'Volver al inicio del mapa', icon: Icons.my_location, onPressed: onReset),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.selected, required this.label, required this.onPressed});

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: selected ? VocesColors.inkOnDesk : VocesColors.marigold,
        shape: CircleBorder(side: BorderSide(color: selected ? VocesColors.inkOnDesk : VocesColors.ink, width: 2)),
        child: InkWell(customBorder: const CircleBorder(), onTap: onPressed, child: const SizedBox.expand()),
      ),
    );
  }
}

class _DraftPin extends StatelessWidget {
  const _DraftPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VocesColors.inkOnDesk, width: 2),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VocesColors.paper,
      shape: const RoundedRectangleBorder(side: BorderSide(color: VocesColors.paperLine)),
      child: IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon, color: VocesColors.ink), constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
    );
  }
}

class _StoryRail extends StatelessWidget {
  const _StoryRail({
    required this.stories,
    required this.visible,
    required this.selectedId,
    required this.placeId,
    required this.narrator,
    required this.category,
    required this.query,
    required this.draft,
    required this.awaitingTap,
    required this.error,
    required this.onQuery,
    required this.onNarrator,
    required this.onCategory,
    required this.onSelect,
    required this.onClearPlace,
    required this.onRead,
    required this.onWrite,
  });

  final List<StoryPin> stories;
  final List<StoryPin> visible;
  final String? selectedId;
  final String? placeId;
  final String? narrator;
  final String? category;
  final TextEditingController query;
  final LatLng? draft;
  final bool awaitingTap;
  final String? error;
  final VoidCallback onQuery;
  final ValueChanged<String?> onNarrator;
  final ValueChanged<String?> onCategory;
  final ValueChanged<StoryPin> onSelect;
  final VoidCallback onClearPlace;
  final ValueChanged<StoryPin> onRead;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    final narrators = {for (final story in stories) story.narratorName ?? ''}.toList()..sort();
    final categories = {for (final story in stories) story.category}.toList()..sort();
    final selected = visible.where((story) => story.id == selectedId).firstOrNull ?? stories.where((story) => story.id == selectedId).firstOrNull;
    return ColoredBox(
      color: VocesColors.desk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('Historias de este mapa', style: vocesDisplay(19, color: VocesColors.inkOnDesk)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: query,
              onChanged: (_) => onQuery(),
              decoration: const InputDecoration(labelText: 'Buscar', isDense: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(child: _Filter(label: 'Quien cuenta', value: narrator, onChanged: onNarrator, options: {for (final name in narrators) name: name.isEmpty ? 'Sin nombre' : name})),
                const SizedBox(width: 8),
                Expanded(child: _Filter(label: 'Tipo', value: category, onChanged: onCategory, options: {for (final item in categories) item: categoryLabel(item)})),
              ],
            ),
          ),
          if (placeId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onClearPlace, child: const Text('Ver todos los lugares de este recuadro')),
            ),
          if (draft != null)
            _DraftBanner(point: draft!, onWrite: onWrite)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                awaitingTap ? 'Pincha el mapa en el sitio exacto de la historia.' : 'Pincha un sitio vacío del mapa para dejar ahí una historia. Pincha un sello para ver las historias de ese lugar.',
                style: vocesSans(size: 13, color: VocesColors.mutedOnDesk, height: 1.5),
              ),
            ),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(error!)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              children: [
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No hay historias con este filtro en el recuadro.', style: TextStyle(color: VocesColors.muted)),
                  ),
                for (final story in visible)
                  _StoryCard(
                    story: story,
                    selected: story.id == selectedId,
                    onSelect: () => onSelect(story),
                  ),
              ],
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onRead(selected),
                  style: TextButton.styleFrom(foregroundColor: VocesColors.marigold),
                  child: const Text('Leer la historia'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.value, required this.onChanged, required this.options});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Map<String, String> options;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('$label-${options.length}-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        for (final entry in options.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.point, required this.onWrite});

  final LatLng point;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Punto marcado', style: vocesDisplay(18)),
          const SizedBox(height: 4),
          Text(coordinateLabel(point), style: vocesMono(size: 11.5)),
          const SizedBox(height: 8),
          Text('Vuelve a pinchar el mapa si este no es el sitio.', style: vocesSans(size: 13)),
          const SizedBox(height: 10),
          FilledButton(onPressed: onWrite, child: const Text('Escribir la historia aquí')),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.selected, required this.onSelect});

  final StoryPin story;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: VocesColors.paper,
        child: InkWell(
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: selected ? VocesColors.marigold : Colors.transparent, width: 4),
                bottom: const BorderSide(color: VocesColors.paperLine),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(story.placeName, style: vocesSans(size: 12.5, color: VocesColors.cobalt, weight: FontWeight.w700))),
                    Text(coordinateLabel(story.point), style: vocesMono(size: 10.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(story.title, style: vocesDisplay(18)),
                if (story.narratorName != null) Text('Lo cuenta ${story.narratorName}', style: vocesSans(size: 12)),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('En el mapa', style: vocesSans(size: 11.5, color: VocesColors.marigoldDeep, weight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
