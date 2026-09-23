import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/theme.dart';

class ReviewQueue extends StatelessWidget {
  const ReviewQueue({super.key, required this.stories, required this.onPublish, required this.onReject});

  final List<StoryPin> stories;
  final ValueChanged<StoryPin> onPublish;
  final ValueChanged<StoryPin> onReject;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const Text('No hay historias en revisión.', style: TextStyle(color: VocesColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final story in stories)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(story.placeName, style: const TextStyle(color: VocesColors.moss)),
                Text(story.title),
                if (story.body != null) Text(story.body!),
                Row(
                  children: [
                    FilledButton(onPressed: () => onPublish(story), child: const Text('Publicar')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => onReject(story), child: const Text('Rechazar')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
