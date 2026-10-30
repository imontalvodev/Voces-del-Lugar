import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/pagina.dart';

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
/// Con [escuchar], el audio empieza a sonar al abrirla.
Future<void> openStory(BuildContext context, StoryPin story, {bool escuchar = false}) {
  return Navigator.push(context, storyRoute(story, escuchar: escuchar));
}

Route<void> storyRoute(StoryPin story, {bool escuchar = false}) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: storyPath(story.id)),
    builder: (_) => StoryPage(story: story, escuchar: escuchar),
  );
}

/// Pantallas a las que se llega escribiendo o pegando una dirección.
Route<void>? vocesRoute(RouteSettings settings) {
  final id = storyIdFromPath(settings.name);
  if (id == null) return null;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => StoryLoader(id: id),
  );
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
        if (snapshot.hasError) return const HistoriaNoEsta();
        return const Scaffold(
          body: SafeArea(
            child: MargenPagina(ancho: 720, child: Cargando(texto: 'Abriendo la historia…', bloques: 1)),
          ),
        );
      },
    );
  }
}
