import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key, required this.story});

  final StoryPin story;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(story.placeName)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 48),
            children: [
              Text(story.placeName, style: const TextStyle(color: VocesColors.moss, fontSize: 16)),
              const SizedBox(height: 8),
              Text(story.title, style: GoogleFonts.newsreader(fontSize: 42, height: 1.05, color: VocesColors.ink)),
              const SizedBox(height: 12),
              Text(
                story.narratorName == null ? 'Sin nombre de quien la cuenta' : 'Lo cuenta ${story.narratorName}',
                style: const TextStyle(fontSize: 18),
              ),
              if (story.body != null) ...[
                const SizedBox(height: 28),
                Text(story.body!, style: const TextStyle(fontSize: 18, height: 1.55)),
              ],
              if (story.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text('Hay una grabación de esta historia.', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                SelectableText(story.mediaUrls.first),
              ],
              const SizedBox(height: 36),
              Text(
                '${storyStatusLabel(story.status)}. ${categoryLabel(story.category)}. Licencia ${licenseLabel(story.license)}.',
                style: const TextStyle(color: VocesColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
