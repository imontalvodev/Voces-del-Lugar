import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/tokens.dart';

String narratorLine(StoryPin story) {
  final name = story.narratorName?.trim();
  return name == null || name.isEmpty ? 'Sin nombre de quien la cuenta' : 'La cuenta $name';
}

/// Tarjeta que se abre en la ficha creciendo desde donde estaba.
class StoryCard extends StatefulWidget {
  const StoryCard({super.key, required this.story, this.showStatus = false});

  final StoryPin story;
  final bool showStatus;

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final hasAudio = story.mediaUrls.isNotEmpty;
    return OpenContainer<void>(
      transitionDuration: Motion.of(context, const Duration(milliseconds: 520)),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: Colors.transparent,
      openColor: Palette.night,
      middleColor: Palette.night,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      tappable: false,
      openBuilder: (context, _) => StoryPage(story: story),
      closedBuilder: (context, open) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Pressable(
            onTap: open,
            semanticLabel: '${story.title}, ${story.placeName}',
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.settle),
              curve: Motion.emphasized,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: _hover ? 0.16 : 0), blurRadius: 40, spreadRadius: -8)],
              ),
              child: Glass(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 15, color: Palette.lamp),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              story.placeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text(size: 13.5, weight: FontWeight.w600, color: Palette.lamp, height: 1.2),
                            ),
                          ),
                          if (hasAudio)
                            Tooltip(
                              message: 'Tiene grabación',
                              child: Icon(LucideIcons.audioWaveform, size: 18, color: Palette.haze),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(30, height: 1.05)),
                      const SizedBox(height: 10),
                      Text(narratorLine(story), style: text(size: 14, color: Palette.haze)),
                      const SizedBox(height: 18),
                      VoicePrint(seed: story.id, bars: 38, height: 30, alive: _hover && hasAudio, dim: !hasAudio),
                      if (widget.showStatus) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            StatusChip(status: story.status),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(categoryLabel(story.category), style: text(size: 13, color: Palette.haze)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
