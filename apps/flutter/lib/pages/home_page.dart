import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/story_card.dart';
import 'package:voces/ui/tokens.dart';
import 'package:voces/ui/voice_terrain.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, required this.onLeaveStory, required this.onOpenMap});

  final VocesApi api;
  final VoidCallback onLeaveStory;
  final VoidCallback onOpenMap;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<StoryPin> _stories = [];
  String? _error;
  bool _loading = true;
  String? _category;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stories = await widget.api.archive();
      if (mounted) setState(() => _stories = stories);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión con el archivo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openById(String id) {
    final story = _stories.where((s) => s.id == id).firstOrNull;
    if (story == null) return;
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StoryPage(story: story)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 720;
    final pad = narrow ? 22.0 : 56.0;
    final filtered = _category == null
        ? _stories
        : [
            for (final s in _stories)
              if (s.category == _category) s,
          ];
    final categories = {for (final s in _stories) s.category}.toList()..sort();
    final beacons = beaconsFromPoints([
      for (final s in _stories) (id: s.id, lat: s.point.latitude, lon: s.point.longitude, label: '${s.title}\n${s.placeName}'),
    ]);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: (size.height * 0.92).clamp(560.0, 980.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: VoiceTerrain(beacons: beacons, onBeacon: _openById, horizon: narrow ? 0.7 : 0.5),
                ),
                Positioned(
                  left: pad,
                  right: pad,
                  top: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(top: narrow ? 28 : 56),
                      child: _Hero(narrow: narrow, onLeaveStory: widget.onLeaveStory, onOpenMap: widget.onOpenMap),
                    ),
                  ),
                ),
                if (beacons.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: narrow ? 118 : 110,
                    child: IgnorePointer(
                      child: Center(
                        child: Glass(
                          radius: 999,
                          tint: Palette.glassStrong.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            beacons.length == 1
                                ? 'La luz es una historia. Tócala para abrirla.'
                                : 'Cada luz es una de las ${beacons.length} historias. Toca una para abrirla.',
                            textAlign: TextAlign.center,
                            style: text(size: 13.5, color: Palette.bone.withValues(alpha: 0.85)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 1800.ms, duration: 800.ms),
                    ),
                  ),
              ],
            ),
          ),
        ),
        DecoratedSliver(
          decoration: const BoxDecoration(color: Palette.deep),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lo último que se ha contado', style: display(narrow ? 36 : 48)),
                      const SizedBox(height: 8),
                      Text(
                        _loading
                            ? 'Buscando en el archivo…'
                            : '${_stories.length} ${_stories.length == 1 ? 'historia publicada' : 'historias publicadas'}',
                        style: text(size: 15, color: Palette.haze),
                      ),
                      if (categories.length > 1) ...[
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              FilterPill(label: 'Todas', selected: _category == null, onTap: () => setState(() => _category = null)),
                              for (final c in categories) ...[
                                const SizedBox(width: 8),
                                FilterPill(
                                  label: categoryLabel(c),
                                  selected: _category == c,
                                  onTap: () => setState(() => _category = _category == c ? null : c),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              SliverPadding(padding: EdgeInsets.fromLTRB(pad, 0, pad, 140), sliver: _body(filtered)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(List<StoryPin> stories) {
    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 420,
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      mainAxisExtent: 232,
    );
    if (_loading) {
      return SliverGrid(
        gridDelegate: grid,
        delegate: SliverChildBuilderDelegate((_, _) => const LoadingSlab(height: 232, radius: 24), childCount: 3),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(
        child: Notice(message: 'No se pudo leer el archivo: $_error', action: 'Reintentar', onAction: reload),
      );
    }
    if (stories.isEmpty) {
      return SliverToBoxAdapter(
        child: Glass(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_category == null ? 'Aún no hay ninguna historia.' : 'No hay historias de este tipo.', style: display(32)),
              const SizedBox(height: 10),
              Text('La primera puede ser la de tu calle, tu plaza o el pueblo de tus abuelos.', style: text(size: 16, color: Palette.haze)),
              const SizedBox(height: 22),
              LampButton(label: 'Dejar la primera', icon: LucideIcons.mic, onPressed: widget.onLeaveStory),
            ],
          ),
        ),
      );
    }
    return SliverGrid(
      gridDelegate: grid,
      delegate: SliverChildBuilderDelegate(
        (context, index) => StoryCard(key: ValueKey(stories[index].id), story: stories[index]),
        childCount: stories.length,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.narrow, required this.onLeaveStory, required this.onOpenMap});

  final bool narrow;
  final VoidCallback onLeaveStory;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    Widget enter(Widget child, Duration delay) {
      if (still) return child;
      return child
          .animate(delay: delay)
          .fadeIn(duration: 900.ms, curve: Motion.out)
          .blurXY(begin: 12, end: 0, duration: 900.ms, curve: Motion.out)
          .moveY(begin: 18, end: 0, duration: 900.ms, curve: Motion.out);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          enter(
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.lamp,
                    boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: 0.8), blurRadius: 12)],
                  ),
                ),
                const SizedBox(width: 10),
                Text('Voces del Lugar', style: text(size: 16, weight: FontWeight.w600)),
              ],
            ),
            200.ms,
          ),
          SizedBox(height: narrow ? 22 : 30),
          enter(Text('Cada sitio guarda algo que alguien contó.', style: display(narrow ? 50 : 88, height: 0.98)), 400.ms),
          const SizedBox(height: 18),
          enter(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Historias que la gente mayor asocia a una calle, una plaza o un pueblo. Escúchalas donde pasaron, o deja la que tú conoces.',
                style: text(size: narrow ? 16 : 18, color: Palette.bone.withValues(alpha: 0.82), height: 1.55),
              ),
            ),
            700.ms,
          ),
          const SizedBox(height: 26),
          enter(
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                LampButton(label: 'Dejar una historia', icon: LucideIcons.mic, onPressed: onLeaveStory),
                GhostButton(label: 'Abrir el mapa', icon: LucideIcons.map, onPressed: onOpenMap),
              ],
            ),
            950.ms,
          ),
        ],
      ),
    );
  }
}
