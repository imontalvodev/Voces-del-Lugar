import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  Widget build(BuildContext context) {
    final lead = _stories.isEmpty ? null : _stories.first;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
          children: [
            if (_loading)
              const StoryListStatus(message: 'Cargando historias', busy: true)
            else if (_error != null)
              StoryListStatus(message: _error!, onRetry: reload)
            else if (lead == null) ...[
              Text('Todavía no hay historias publicadas.', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              const Text('La primera puede ser la de una calle, una plaza o un pueblo que conozcas de cerca.'),
              const SizedBox(height: 20),
              Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: widget.onLeaveStory, child: const Text('Dejar una historia'))),
            ] else ...[
              Text(lead.placeName, style: const TextStyle(color: VocesColors.moss, fontSize: 16)),
              const SizedBox(height: 8),
              Text(lead.title, style: GoogleFonts.newsreader(fontSize: 44, height: 1.05, color: VocesColors.ink)),
              if (lead.narratorName != null) ...[
                const SizedBox(height: 12),
                Text('Lo cuenta ${lead.narratorName}', style: const TextStyle(fontSize: 18)),
              ],
              if (excerpt(lead.body, max: 320).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(excerpt(lead.body, max: 320), style: const TextStyle(fontSize: 18, height: 1.5)),
              ],
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _open(lead), child: const Text('Leer la historia'))),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: widget.onLeaveStory, child: const Text('Dejar una historia'))),
              if (_stories.length > 1) ...[
                const SizedBox(height: 28),
                ChronicleList(stories: _stories.skip(1).toList(), onOpen: _open),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
