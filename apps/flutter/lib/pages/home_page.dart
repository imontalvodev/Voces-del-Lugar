import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';
import 'package:voces/widgets/story_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, required this.onLeaveStory});

  final VocesApi api;
  final VoidCallback onLeaveStory;

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
      if (!mounted) return;
      setState(() => _stories = stories);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(StoryPin story) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage(story: story)));
  }

  List<StoryPin> get _filtered {
    if (_category == null) return _stories;
    return [for (final story in _stories) if (story.category == _category) story];
  }

  @override
  Widget build(BuildContext context) {
    final stories = _filtered;
    final lead = stories.isEmpty ? null : stories.first;
    final rest = stories.length > 1 ? stories.skip(1).toList() : const <StoryPin>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 48),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: ColoredBox(color: VocesColors.marigold, child: SizedBox(width: 64, height: 6)),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const StoryListStatus(message: 'Cargando historias', busy: true, onDesk: true)
        else if (_error != null)
          StoryListStatus(message: _error!, onRetry: reload, onDesk: true)
        else if (lead == null) ...[
          Text(
            _category == null ? 'Todavía no hay historias publicadas.' : 'No hay historias de este tipo.',
            style: vocesDisplay(32, color: VocesColors.inkOnDesk),
          ),
          const SizedBox(height: 16),
          Text(
            'La primera puede ser la de una calle, una plaza o un pueblo que conozcas de cerca.',
            style: vocesSans(size: 16, color: VocesColors.inkOnDesk),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: widget.onLeaveStory, child: const Text('Dejar una historia aquí')),
          ),
        ] else ...[
          _LeadCard(story: lead, onRead: () => _open(lead), onLeave: widget.onLeaveStory),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Catálogo', style: vocesDisplay(22, color: VocesColors.inkOnDesk)),
              const Spacer(),
              Text(
                '${_stories.length} ${_stories.length == 1 ? 'historia publicada' : 'historias publicadas'}',
                style: vocesMono(size: 13, color: VocesColors.mutedOnDesk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final category in const ['anecdota', 'leyenda', 'oficio', 'tradicion', 'evento'])
                _CategoryChip(
                  label: categoryLabel(category),
                  selected: _category == category,
                  onTap: () => setState(() => _category = _category == category ? null : category),
                ),
            ],
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980 ? 3 : (constraints.maxWidth >= 640 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rest.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 148,
                  ),
                  itemBuilder: (context, index) => CatalogCard(story: rest[index], onOpen: () => _open(rest[index])),
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.story, required this.onRead, required this.onLeave});

  final StoryPin story;
  final VoidCallback onRead;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VocesColors.paper,
      padding: const EdgeInsets.fromLTRB(36, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(coordinateLabel(story.point), style: vocesMono()),
          ),
          Text(story.placeName, style: vocesSans(size: 13.5, color: VocesColors.cobalt, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(story.title, style: vocesDisplay(38)),
          const SizedBox(height: 10),
          Text(
            story.narratorName == null ? 'Sin nombre de quien la cuenta' : 'Lo cuenta ${story.narratorName}',
            style: vocesSans(size: 15),
          ),
          if (excerpt(story.body, max: 320).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(excerpt(story.body, max: 320), style: vocesSans(size: 15.5, height: 1.55)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(onPressed: onRead, child: const Text('Leer la historia completa')),
              TextButton(onPressed: onLeave, child: const Text('Dejar una historia aquí')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? VocesColors.ink : VocesColors.mutedOnDesk;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? VocesColors.marigold : Colors.transparent,
            border: Border.all(color: selected ? VocesColors.marigold : VocesColors.mutedOnDesk, width: 1.5),
          ),
          child: Text(label, style: vocesSans(size: 13, color: color, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
