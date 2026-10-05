import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/tokens.dart';

/// La dirección propia de cada historia, para poder compartirla.
String storyPath(String id) => '/historia/$id';

/// El enlace completo, con la dirección por la que se entró a la app.
String storyLink(String id, Uri page) => '${page.origin}${storyPath(id)}';

String? storyIdFromPath(String? path) {
  final match = RegExp(r'^/historia/([^/]+)$').firstMatch(path ?? '');
  return match?.group(1);
}

/// Abre una historia dejando su dirección en la barra del navegador, así el
/// botón de atrás vuelve donde se estaba y el enlace se puede pasar a otro.
Future<void> openStory(BuildContext context, StoryPin story) {
  return Navigator.push(context, storyRoute(story));
}

Route<void> storyRoute(StoryPin story) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: storyPath(story.id)),
    builder: (_) => StoryPage(story: story),
  );
}

/// Pantallas a las que se llega escribiendo o pegando una dirección.
Route<void>? vocesRoute(RouteSettings settings) {
  final id = storyIdFromPath(settings.name);
  if (id == null) return null;
  return MaterialPageRoute<void>(settings: settings, builder: (_) => StoryLoader(id: id));
}

/// Trae por su id la historia de un enlace y la abre; si no existe, lo dice.
class StoryLoader extends StatefulWidget {
  const StoryLoader({super.key, required this.id, this.load, this.page});

  final String id;
  final Future<StoryPin> Function(String id)? load;
  final Widget Function(StoryPin story)? page;

  @override
  State<StoryLoader> createState() => _StoryLoaderState();
}

class _StoryLoaderState extends State<StoryLoader> {
  Future<StoryPin>? _story;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _story ??= (widget.load ?? ApiScope.of(context).story)(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoryPin>(
      future: _story,
      builder: (context, snapshot) {
        final story = snapshot.data;
        if (story != null) return (widget.page ?? (s) => StoryPage(story: s))(story);
        return Scaffold(
          backgroundColor: Palette.night,
          body: Sky(
            child: Center(
              child: snapshot.hasError ? const _Missing() : const SizedBox(width: 280, child: LoadingSlab(height: 120)),
            ),
          ),
        );
      },
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta historia no está', style: display(44)),
            const SizedBox(height: 12),
            Text(
              'Puede que la hayan retirado para revisarla o que el enlace llegara cortado. Las demás siguen en el mapa.',
              style: text(color: Palette.haze),
            ),
            const SizedBox(height: 24),
            LampButton(
              label: 'Ir al inicio',
              icon: LucideIcons.house,
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
