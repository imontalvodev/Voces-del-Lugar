import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/dusk_tiles.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/story_card.dart';
import 'package:voces/ui/tokens.dart';

const _home = LatLng(40.416, -3.703);

/// Espacio que deja libre el dock de navegación al pie.
const dockClearance = 104.0;

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.api, required this.onLeaveStory});

  final VocesApi api;
  final void Function(LatLng point) onLeaveStory;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final _map = MapController();
  final _query = TextEditingController();
  late final AnimationController _flight = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  VoidCallback? _flightStep;
  final _sheet = DraggableScrollableController();
  Timer? _debounce;
  List<StoryPin> _stories = [];
  String? _selectedId;
  String? _category;
  LatLng? _draft;
  String? _error;
  bool _ready = false;
  bool _placing = false;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _sheet.dispose();
    _flight.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Pone el mapa en modo "marcar sitio" (lo usa el botón de la portada).
  void beginPlacing() {
    setState(() {
      _placing = true;
      _selectedId = null;
    });
  }

  List<StoryPin> get _visible {
    final q = _query.text.trim().toLowerCase();
    return [
      for (final story in _stories)
        if ((_category == null || story.category == _category) &&
            (q.isEmpty || '${story.title} ${story.placeName} ${story.narratorName ?? ''} ${story.body ?? ''}'.toLowerCase().contains(q)))
          story,
    ];
  }

  StoryPin? get _selected => _stories.where((s) => s.id == _selectedId).firstOrNull;

  Future<void> reload() async {
    if (!_ready) return;
    final bounds = _map.camera.visibleBounds;
    setState(() => _loading = true);
    try {
      final stories = await widget.api.mapStories(bounds.west, bounds.south, bounds.east, bounds.north);
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _error = null;
        if (_selectedId != null && stories.every((s) => s.id != _selectedId)) _selectedId = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión con el archivo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), reload);
  }

  /// Vuela la cámara: se aleja un poco a mitad de camino si el salto es largo,
  /// como quien levanta la vista antes de volver a mirar de cerca.
  void _flyTo(LatLng to, double zoom) {
    if (!_ready) return;
    final from = _map.camera.center;
    final fromZoom = _map.camera.zoom;
    if (MediaQuery.disableAnimationsOf(context)) {
      _map.move(to, zoom);
      _scheduleReload();
      return;
    }
    final distanceKm = const Distance().as(LengthUnit.Kilometer, from, to);
    final dip = math.min(3.0, math.log(1 + distanceKm) / 2);
    final curve = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    if (_flightStep != null) _flight.removeListener(_flightStep!);
    _flightStep = () {
      final t = curve.value;
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lon = from.longitude + (to.longitude - from.longitude) * t;
      final z = fromZoom + (zoom - fromZoom) * t - dip * math.sin(math.pi * t);
      _map.move(LatLng(lat, lon), z);
    };
    _flight
      ..addListener(_flightStep!)
      ..forward(from: 0).whenComplete(_scheduleReload);
  }

  /// En móvil, abre la hoja lo justo para que se vea la acción principal.
  void _raiseSheet() {
    if (!_sheet.isAttached || _sheet.size >= _sheetFocus) return;
    _sheet.animateTo(_sheetFocus, duration: Motion.of(context, Motion.settle), curve: Motion.emphasized);
  }

  void _select(StoryPin story) {
    setState(() {
      _selectedId = story.id;
      _draft = null;
      _placing = false;
    });
    _raiseSheet();
    final zoom = math.max(_map.camera.zoom, 15.5);
    var target = story.point;
    final size = MediaQuery.sizeOf(context);
    if (size.width < 900) {
      // La hoja tapa la mitad de abajo: el centro baja para que la farola
      // quede en el hueco visible de arriba.
      final projected = _map.camera.projectAtZoom(target, zoom);
      target = _map.camera.unprojectAtZoom(projected.translate(0, size.height * 0.28), zoom);
    }
    _flyTo(target, zoom);
  }

  void _drop(LatLng point) {
    setState(() {
      _draft = point;
      _placing = false;
      _selectedId = null;
    });
    _raiseSheet();
  }

  void _zoom(double delta) {
    final camera = _map.camera;
    _flyTo(camera.center, (camera.zoom + delta).clamp(3.0, 18.0));
  }

  void _open(StoryPin story) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StoryPage(story: story)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final visible = _visible;
    final panel = _Panel(
      visible: visible,
      total: _stories.length,
      selected: _selected,
      draft: _draft,
      placing: _placing,
      loading: _loading,
      error: _error,
      onSelect: _select,
      onOpen: _open,
      onWrite: (point) => widget.onLeaveStory(point),
      onClearDraft: () => setState(() => _draft = null),
      onClearSelection: () => setState(() => _selectedId = null),
      onRetry: reload,
    );

    return Stack(
      children: [
        Positioned.fill(child: _canvas(visible)),
        Positioned(
          left: 16,
          right: 16,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: wide ? Alignment.topLeft : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 400 : 640),
                  child: _SearchBar(
                    controller: _query,
                    categories: ({for (final s in _stories) s.category}.toList()..sort()),
                    category: _category,
                    onChanged: () => setState(() {}),
                    onCategory: (value) => setState(() => _category = value),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 0,
          bottom: wide ? dockClearance : size.height * 0.4,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _PlaceToggle(active: _placing, onTap: () => setState(() => _placing = !_placing)),
                const SizedBox(height: 10),
                GlassIconButton(icon: LucideIcons.plus, tooltip: 'Acercar', onPressed: () => _zoom(1)),
                const SizedBox(height: 8),
                GlassIconButton(icon: LucideIcons.minus, tooltip: 'Alejar', onPressed: () => _zoom(-1)),
                const SizedBox(height: 8),
                GlassIconButton(icon: LucideIcons.locateFixed, tooltip: 'Volver a Madrid', onPressed: () => _flyTo(_home, 13)),
              ],
            ),
          ),
        ),
        if (_placing)
          Positioned(
            left: 0,
            right: 0,
            top: wide ? null : 150,
            bottom: wide ? dockClearance + 12 : null,
            child: Center(
              child: Glass(
                radius: 999,
                tint: Palette.glassStrong,
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.pointer, size: 18, color: Palette.lamp),
                    const SizedBox(width: 10),
                    Text('Toca el mapa donde pasó la historia', style: text(size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    TextButton(onPressed: () => setState(() => _placing = false), child: const Text('Cancelar')),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 240.ms).moveY(begin: -10, end: 0, curve: Motion.out),
          ),
        Positioned(
          left: 16,
          bottom: wide ? 22 : null,
          top: wide ? null : 0,
          child: IgnorePointer(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: wide ? 0 : 128),
                child: Text('© colaboradores de OpenStreetMap', style: text(size: 11, color: Palette.haze.withValues(alpha: 0.8))),
              ),
            ),
          ),
        ),
        if (wide)
          Positioned(
            left: 16,
            top: 150,
            bottom: dockClearance,
            width: 400,
            child: Glass(radius: 26, tint: Palette.glassStrong.withValues(alpha: 0.55), child: panel),
          )
        else
          _MobileSheet(controller: _sheet, child: panel),
      ],
    );
  }

  Widget _canvas(List<StoryPin> visible) {
    final selected = _selected;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _home,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 18.5,
        backgroundColor: Palette.deep,
        onMapReady: () {
          _ready = true;
          reload();
        },
        onTap: (_, point) {
          if (_placing || _selectedId == null) {
            _drop(point);
          } else {
            setState(() => _selectedId = null);
          }
        },
        onLongPress: (_, point) => _drop(point),
        onMapEvent: (event) {
          if (event.source != MapEventSource.mapController && event.source != MapEventSource.nonRotatedSizeChange) {
            _scheduleReload();
          }
        },
      ),
      children: [
        duskTiles(),
        MarkerLayer(
          markers: [
            for (final story in visible)
              if (story.id != _selectedId)
                Marker(
                  point: story.point,
                  width: 44,
                  height: 44,
                  child: LampPin(label: story.title, selected: false, onTap: () => _select(story)),
                ),
            if (selected != null)
              Marker(
                point: selected.point,
                width: 96,
                height: 96,
                child: LampPin(label: selected.title, selected: true, onTap: () => _open(selected)),
              ),
            if (_draft != null)
              Marker(
                point: _draft!,
                width: 60,
                height: 76,
                alignment: Alignment.topCenter,
                child: DraftPin(key: ValueKey(_draft)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Pin de una historia: una farola. La elegida late con anillos de sonido.
class LampPin extends StatefulWidget {
  const LampPin({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<LampPin> createState() => _LampPinState();
}

class _LampPinState extends State<LampPin> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  var _hover = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LampPin old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.selected && !MediaQuery.disableAnimationsOf(context);
    if (run && !_pulse.isAnimating) _pulse.repeat();
    if (!run) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              painter: _LampPinPainter(phase: _pulse.value, selected: widget.selected, hover: _hover),
            ),
          ),
        ),
      ),
    );
  }
}

class _LampPinPainter extends CustomPainter {
  _LampPinPainter({required this.phase, required this.selected, required this.hover});

  final double phase;
  final bool selected;
  final bool hover;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final core = selected ? 9.0 : (hover ? 7.5 : 6.0);
    if (selected) {
      for (var i = 0; i < 2; i++) {
        final t = (phase + i / 2) % 1.0;
        canvas.drawCircle(
          c,
          core + t * size.shortestSide * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Palette.lamp.withValues(alpha: (1 - t) * 0.7),
        );
      }
    }
    final halo = core * (selected ? 3.2 : 2.6);
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..shader = RadialGradient(colors: [Palette.lamp.withValues(alpha: 0.55), Palette.ember.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: halo)),
    );
    canvas.drawCircle(c, core, Paint()..color = Palette.lamp);
    canvas.drawCircle(c, core * 0.45, Paint()..color = const Color(0xFFFFF3DE));
  }

  @override
  bool shouldRepaint(covariant _LampPinPainter old) => old.phase != phase || old.selected != selected || old.hover != hover;
}

/// Marca provisional: cae y rebota sobre el sitio tocado.
class DraftPin extends StatelessWidget {
  const DraftPin({super.key});

  @override
  Widget build(BuildContext context) {
    final pin = Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Palette.dusk, Palette.ember]),
            border: Border.all(color: Palette.bone, width: 2.5),
            boxShadow: [BoxShadow(color: Palette.dusk.withValues(alpha: 0.6), blurRadius: 18)],
          ),
          child: const Icon(LucideIcons.mic, size: 18, color: Palette.deep),
        ),
        Container(width: 2.5, height: 26, color: Palette.bone),
        Container(
          width: 8,
          height: 3,
          decoration: BoxDecoration(color: Palette.deep.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) return pin;
    return pin.animate().moveY(begin: -60, end: 0, duration: 620.ms, curve: Curves.bounceOut).fadeIn(duration: 160.ms);
  }
}

class _PlaceToggle extends StatelessWidget {
  const _PlaceToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Dejar de marcar' : 'Marcar un sitio para contar su historia',
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'Marcar un sitio',
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.settle),
          curve: Motion.emphasized,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active ? null : Palette.lampGlow,
            color: active ? Palette.bone : null,
            boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: 0.45), blurRadius: 24)],
          ),
          child: Icon(active ? LucideIcons.x : LucideIcons.mapPinPlus, color: Palette.deep, size: 24),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.categories,
    required this.category,
    required this.onChanged,
    required this.onCategory,
  });

  final TextEditingController controller;
  final List<String> categories;
  final String? category;
  final VoidCallback onChanged;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Glass(
          radius: 999,
          tint: Palette.glassStrong.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 20, color: Palette.haze),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  style: text(size: 15.5),
                  decoration: const InputDecoration(
                    hintText: 'Buscar un sitio, una persona, un recuerdo',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar la búsqueda',
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                  icon: const Icon(LucideIcons.x, size: 18, color: Palette.haze),
                ),
            ],
          ),
        ),
        if (categories.length > 1) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final c in categories) ...[
                  FilterPill(label: categoryLabel(c), selected: category == c, onTap: () => onCategory(category == c ? null : c)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Alturas de la hoja en móvil: plegada, a medias y con el foco abierto.
const _sheetRest = 0.36;
const _sheetFocus = 0.66;

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({required this.controller, required this.child});

  final DraggableScrollableController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final min = ((dockClearance + 96) / height).clamp(0.12, 0.5);
    return DraggableScrollableSheet(
      controller: controller,
      minChildSize: min,
      initialChildSize: math.max(min, _sheetRest),
      maxChildSize: 0.88,
      snap: true,
      snapSizes: [math.max(min, _sheetRest), _sheetFocus],
      builder: (context, scroll) {
        return Glass(
          radius: 30,
          tint: Palette.glassStrong.withValues(alpha: 0.7),
          child: PrimaryScrollController(controller: scroll, child: child),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.visible,
    required this.total,
    required this.selected,
    required this.draft,
    required this.placing,
    required this.loading,
    required this.error,
    required this.onSelect,
    required this.onOpen,
    required this.onWrite,
    required this.onClearDraft,
    required this.onClearSelection,
    required this.onRetry,
  });

  final List<StoryPin> visible;
  final int total;
  final StoryPin? selected;
  final LatLng? draft;
  final bool placing;
  final bool loading;
  final String? error;
  final ValueChanged<StoryPin> onSelect;
  final ValueChanged<StoryPin> onOpen;
  final ValueChanged<LatLng> onWrite;
  final VoidCallback onClearDraft;
  final VoidCallback onClearSelection;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final s in visible)
        if (s.id != selected?.id) s,
    ];
    final focus = draft != null
        ? _DraftFocus(key: const ValueKey('draft'), point: draft!, onWrite: () => onWrite(draft!), onClear: onClearDraft)
        : selected != null
        ? _StoryFocus(key: ValueKey(selected!.id), story: selected!, onOpen: () => onOpen(selected!), onClose: onClearSelection)
        : null;
    return CustomScrollView(
      primary: true,
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Palette.haze.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AnimatedSize(
              duration: Motion.of(context, Motion.settle),
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.settle),
                switchInCurve: Motion.out,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: focus ?? _Heading(key: const ValueKey('heading'), count: visible.length, total: total, loading: loading),
              ),
            ),
          ),
        ),
        if (error != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Notice(message: error!, action: 'Reintentar', onAction: onRetry),
            ),
          ),
        if (focus != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Text('Más historias en esta vista', style: text(size: 14, color: Palette.haze)),
            ),
          ),
        if (visible.isEmpty && !loading && error == null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Aquí no hay historias con esa búsqueda. Aleja el mapa o toca un sitio para contar la primera.',
                style: text(size: 14.5, color: Palette.haze),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, dockClearance + 16),
          sliver: SliverList.builder(
            itemCount: others.length,
            itemBuilder: (context, index) {
              final story = others[index];
              return _Row(story: story, selected: story.id == selected?.id, onTap: () => onSelect(story));
            },
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({super.key, required this.count, required this.total, required this.loading});

  final int count;
  final int total;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loading && total == 0 ? 'Buscando historias…' : (count == 1 ? 'Una historia en esta vista' : '$count historias en esta vista'),
          style: display(30),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca una luz para escucharla. Toca un sitio vacío, o mantén pulsado, para contar lo que pasó allí.',
          style: text(size: 14, color: Palette.haze),
        ),
      ],
    );
  }
}

class _StoryFocus extends StatelessWidget {
  const _StoryFocus({super.key, required this.story, required this.onOpen, required this.onClose});

  final StoryPin story;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.mapPin, size: 15, color: Palette.lamp),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                story.placeName,
                style: text(size: 14, weight: FontWeight.w600, color: Palette.lamp),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(LucideIcons.x, size: 18, color: Palette.haze),
            ),
          ],
        ),
        Text(story.title, style: display(34)),
        const SizedBox(height: 8),
        Text(narratorLine(story), style: text(size: 14.5, color: Palette.haze)),
        if (excerpt(story.body, max: 160).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(excerpt(story.body, max: 160), style: text(size: 15, color: Palette.bone.withValues(alpha: 0.85))),
        ],
        const SizedBox(height: 16),
        VoicePrint(seed: story.id, height: 28, alive: story.mediaUrls.isNotEmpty, dim: story.mediaUrls.isEmpty),
        const SizedBox(height: 18),
        LampButton(
          label: story.mediaUrls.isNotEmpty ? 'Escuchar la historia' : 'Leer la historia',
          icon: story.mediaUrls.isNotEmpty ? LucideIcons.headphones : LucideIcons.bookOpenText,
          onPressed: onOpen,
          expand: true,
        ),
      ],
    );
  }
}

class _DraftFocus extends StatelessWidget {
  const _DraftFocus({super.key, required this.point, required this.onWrite, required this.onClear});

  final LatLng point;
  final VoidCallback onWrite;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué pasó aquí?', style: display(36)),
        const SizedBox(height: 6),
        Text(coordinateLabel(point), style: text(size: 14, color: Palette.haze)),
        const SizedBox(height: 6),
        Text('Si no es el sitio exacto, toca otra vez el mapa.', style: text(size: 14, color: Palette.haze)),
        const SizedBox(height: 18),
        LampButton(label: 'Contar la historia de este sitio', icon: LucideIcons.mic, onPressed: onWrite, expand: true),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: onClear, child: const Text('Quitar la marca')),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.story, required this.selected, required this.onTap});

  final StoryPin story;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      lift: false,
      semanticLabel: '${story.title}, ${story.placeName}',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.settle),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected ? Palette.lamp.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: VoicePrint(seed: story.id, bars: 9, height: 34, dim: story.mediaUrls.isEmpty),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(21, height: 1.1)),
                    const SizedBox(height: 3),
                    Text(
                      story.placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text(size: 13, color: Palette.haze),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: Palette.haze),
            ],
          ),
        ),
      ),
    );
  }
}
