import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/audio.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/story_card.dart';
import 'package:voces/ui/tokens.dart';
import 'package:voces/ui/voice_terrain.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.story});

  final StoryPin story;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _energy = ValueNotifier<double>(0.35);

  @override
  void dispose() {
    _energy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 600 ? 46.0 : 72.0;
    final body = story.body?.trim() ?? '';
    final fade = !MediaQuery.disableAnimationsOf(context);
    Widget reveal(Widget child, int order) {
      if (!fade) return child;
      return child
          .animate(delay: (160 + order * 70).ms)
          .fadeIn(duration: 520.ms, curve: Motion.out)
          .moveY(begin: 14, end: 0, duration: 520.ms, curve: Motion.out);
    }

    return Scaffold(
      backgroundColor: Palette.night,
      body: Sky(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: width < 600 ? 280 : 360,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.white, Colors.transparent],
                          stops: [0, 0.62, 1],
                        ).createShader(rect),
                        child: VoiceTerrain(
                          rows: 26,
                          horizon: 0.3,
                          energy: _energy,
                          selectedId: story.id,
                          beacons: [TerrainBeacon(id: story.id, x: 0.0, z: 0.55, label: story.placeName)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GlassIconButton(
                            icon: LucideIcons.arrowLeft,
                            tooltip: 'Volver',
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(width < 600 ? 22 : 32, 0, width < 600 ? 22 : 32, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        reveal(
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.mapPin, size: 17, color: Palette.lamp),
                                  const SizedBox(width: 6),
                                  Text(
                                    story.placeName,
                                    style: text(size: 16, weight: FontWeight.w600, color: Palette.lamp),
                                  ),
                                ],
                              ),
                              Text(coordinateLabel(story.point), style: text(size: 13.5, color: Palette.haze)),
                            ],
                          ),
                          0,
                        ),
                        const SizedBox(height: 16),
                        reveal(Text(story.title, style: display(titleSize)), 1),
                        const SizedBox(height: 16),
                        reveal(Text(narratorLine(story), style: text(size: 18, color: Palette.bone.withValues(alpha: 0.86))), 2),
                        if (story.mediaUrls.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          reveal(StoryPlayer(url: story.mediaUrls.first, seed: story.id, energy: _energy), 3),
                        ],
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 36),
                          reveal(SelectableText(body, style: text(size: 19, height: 1.72, color: Palette.bone.withValues(alpha: 0.94))), 4),
                        ],
                        const SizedBox(height: 44),
                        Container(height: 1, color: Palette.glassEdge),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(status: story.status),
                            Text(categoryLabel(story.category), style: text(size: 14, color: Palette.haze)),
                            Text('Licencia ${licenseLabel(story.license)}', style: text(size: 14, color: Palette.haze)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
