import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';

class CatalogCard extends StatelessWidget {
  const CatalogCard({super.key, required this.story, required this.onOpen, this.selected = false});

  final StoryPin story;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VocesColors.paper,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? VocesColors.marigold : VocesColors.paperLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.placeName,
                      style: vocesSans(size: 12.5, color: VocesColors.cobalt, weight: FontWeight.w700),
                    ),
                  ),
                  Text(coordinateLabel(story.point), style: vocesMono(size: 10.5)),
                ],
              ),
              const SizedBox(height: 4),
              Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: vocesDisplay(19)),
              const SizedBox(height: 6),
              Text(
                story.narratorName == null ? 'Sin nombre de quien la cuenta' : 'Lo cuenta ${story.narratorName}',
                style: vocesSans(size: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChronicleList extends StatelessWidget {
  const ChronicleList({
    super.key,
    required this.stories,
    required this.onOpen,
    this.selectedId,
    this.showStatus = false,
  });

  final List<StoryPin> stories;
  final ValueChanged<StoryPin> onOpen;
  final String? selectedId;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final story in stories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogCard(story: story, selected: story.id == selectedId, onOpen: () => onOpen(story)),
                if (showStatus)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: StatusStamp(status: story.status),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class StatusStamp extends StatelessWidget {
  const StatusStamp({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, dashed) = switch (status) {
      'published' => (VocesColors.crimson, false),
      'rejected' => (VocesColors.rejected, false),
      _ => (VocesColors.pending, true),
    };
    final label = storyStatusLabel(status);
    return CustomPaint(
      painter: _StampPainter(color: color, dashed: dashed),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(label, style: vocesSans(size: 12, color: color, weight: FontWeight.w700, height: 1.2)),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(999));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (!dashed) {
      canvas.drawRRect(rect, paint);
      return;
    }
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) => oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class StoryListStatus extends StatelessWidget {
  const StoryListStatus({super.key, required this.message, this.busy = false, this.onRetry, this.onDesk = false});

  final String message;
  final bool busy;
  final VoidCallback? onRetry;
  final bool onDesk;

  @override
  Widget build(BuildContext context) {
    final color = onDesk ? VocesColors.mutedOnDesk : VocesColors.muted;
    if (busy) {
      return Semantics(
        label: message,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LoadingBar(onDesk: onDesk),
            const SizedBox(height: 8),
            _LoadingBar(onDesk: onDesk),
            const SizedBox(height: 8),
            _LoadingBar(onDesk: onDesk, widthFactor: 0.55),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: vocesSans(size: 15, color: color)),
        if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({this.widthFactor = 1, this.onDesk = false});

  final double widthFactor;
  final bool onDesk;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SizedBox(height: 72, child: ColoredBox(color: onDesk ? VocesColors.paper.withValues(alpha: 0.18) : VocesColors.paper)),
    );
  }
}
