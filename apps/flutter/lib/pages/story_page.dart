import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';
import 'package:voces/widgets/story_list.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key, required this.story});

  final StoryPin story;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VocesColors.desk,
      appBar: AppBar(title: const Text('Ficha')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
            children: [
              Container(
                color: VocesColors.paper,
                padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.placeName, style: vocesSans(size: 14, color: VocesColors.cobalt, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(coordinateLabel(story.point), style: vocesMono(size: 12.5)),
                    const SizedBox(height: 14),
                    Text(story.title, style: vocesDisplay(40)),
                    const SizedBox(height: 12),
                    Text(
                      story.narratorName == null ? 'Sin nombre de quien la cuenta' : 'Lo cuenta ${story.narratorName}',
                      style: vocesSans(size: 16),
                    ),
                    if (story.body != null && story.body!.trim().isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text(story.body!, style: vocesSans(size: 16.5, height: 1.6)),
                    ],
                    if (story.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Container(
                        color: VocesColors.desk,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const _PlayMark(),
                            const SizedBox(width: 14),
                            Expanded(child: _Wave()),
                            const SizedBox(width: 12),
                            Flexible(
                              child: SelectableText(
                                'Grabación',
                                style: vocesMono(size: 12, color: VocesColors.mutedOnDesk),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(story.mediaUrls.first, style: vocesMono(size: 12, color: VocesColors.mutedOnDesk)),
                    ],
                    const SizedBox(height: 28),
                    const Divider(height: 1, color: VocesColors.paperLine),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusStamp(status: story.status),
                        Text(
                          '${categoryLabel(story.category)} · Licencia ${licenseLabel(story.license)}',
                          style: vocesSans(size: 13.5, color: VocesColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayMark extends StatelessWidget {
  const _PlayMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: VocesColors.marigold, shape: BoxShape.circle),
      child: const Icon(Icons.play_arrow, color: VocesColors.ink),
    );
  }
}

class _Wave extends StatelessWidget {
  static const _heights = <double>[14, 26, 18, 32, 22, 36, 16, 28, 20, 34, 24, 14, 30, 18, 26, 12, 32, 20];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _heights.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 3,
                height: _heights[i],
                color: i < 8 ? VocesColors.cobalt : VocesColors.mutedOnDesk,
              ),
            ),
        ],
      ),
    );
  }
}
