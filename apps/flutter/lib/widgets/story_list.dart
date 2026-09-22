import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';

class ChronicleList extends StatelessWidget {
  const ChronicleList({
    super.key,
    required this.stories,
    required this.onOpen,
    this.selectedId,
    this.showStatus = false,
    this.lead = false,
  });

  final List<StoryPin> stories;
  final ValueChanged<StoryPin> onOpen;
  final String? selectedId;
  final bool showStatus;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < stories.length; i++)
          _Entry(
            story: stories[i],
            first: lead && i == 0,
            selected: stories[i].id == selectedId,
            showStatus: showStatus,
            onOpen: () => onOpen(stories[i]),
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.story,
    required this.first,
    required this.selected,
    required this.showStatus,
    required this.onOpen,
  });

  final StoryPin story;
  final bool first;
  final bool selected;
  final bool showStatus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final place = story.narratorName == null ? story.placeName : '${story.placeName}, lo cuenta ${story.narratorName}';
    return InkWell(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: first ? 20 : 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VocesColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place, style: const TextStyle(color: VocesColors.moss)),
            const SizedBox(height: 4),
            Text(story.title, style: GoogleFonts.newsreader(fontSize: first ? 32 : 22, height: 1.15, color: VocesColors.ink)),
            if (excerpt(story.body).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(excerpt(story.body, max: first ? 280 : 140), style: TextStyle(color: VocesColors.ink.withValues(alpha: 0.9))),
            ],
            if (showStatus) ...[
              const SizedBox(height: 6),
              Text(storyStatusLabel(story.status), style: const TextStyle(color: VocesColors.muted)),
            ],
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('En el mapa', style: TextStyle(color: VocesColors.seal)),
              ),
          ],
        ),
      ),
    );
  }
}

class StoryListStatus extends StatelessWidget {
  const StoryListStatus({super.key, required this.message, this.busy = false, this.onRetry});

  final String message;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Semantics(
        label: 'Cargando historias',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LoadingBar(),
            SizedBox(height: 8),
            _LoadingBar(),
            SizedBox(height: 8),
            _LoadingBar(widthFactor: 0.55),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: VocesColors.muted)),
        if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({this.widthFactor = 1});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: const SizedBox(height: 56, child: ColoredBox(color: VocesColors.paper)),
    );
  }
}
