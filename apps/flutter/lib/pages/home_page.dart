import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/links.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/estados.dart';
import 'package:voces/ui/ficha.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/sello.dart';

/// Inicio: qué es esto, las dos acciones y lo último que se ha publicado.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, required this.onLeaveStory, required this.onOpenMap});

  final VocesApi api;
  final VoidCallback onLeaveStory;
  final VoidCallback onOpenMap;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<StoryPin> _stories = [];
  bool _sinConexion = false;
  bool _loading = true;
  String? _category;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    widget.api.changes.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    widget.api.changes.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    if (!mounted) return;
    final ticket = ++_ticket;
    setState(() {
      _loading = _stories.isEmpty;
      _sinConexion = false;
    });
    try {
      final stories = await widget.api.archive();
      if (mounted && ticket == _ticket) setState(() => _stories = stories);
    } catch (_) {
      if (mounted && ticket == _ticket) setState(() => _sinConexion = true);
    } finally {
      if (mounted && ticket == _ticket) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = tamano(context);
    final amplio = ancho != Vdl.compacto;
    final visibles = [
      for (final s in _stories)
        if (_category == null || s.category == _category) s,
    ];
    final acciones = [
      BotonPlaca(
        etiqueta: 'Dejar una historia',
        icono: LucideIcons.mic,
        expandir: !amplio,
        onPressed: widget.onLeaveStory,
      ),
      BotonPlaca(
        etiqueta: 'Abrir el mapa',
        icono: LucideIcons.map,
        variante: VarianteBoton.secundario,
        expandir: !amplio,
        onPressed: widget.onOpenMap,
      ),
    ];
    final chips = [
      for (final categoria in [null, ...storyCategories])
        ChipTipo(
          categoria: categoria,
          elegido: _category == categoria,
          onPressed: () => setState(() => _category = categoria),
        ),
    ];
    return RefreshIndicator(
      onRefresh: reload,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: MargenPagina(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ancho == Vdl.compacto) ...[const Marca(pequena: true), const SizedBox(height: 18)],
                    const TituloPantalla('Las historias de cada sitio, contadas por quien las vivió.', grande: true),
                    const Entradilla(
                      'Graba o escribe lo que pasó, márcalo en el mapa y quedará guardado para quien venga después.',
                    ),
                    const SizedBox(height: 24),
                    if (amplio)
                      Wrap(spacing: 12, runSpacing: 12, children: acciones)
                    else
                      Column(children: [acciones[0], const SizedBox(height: 12), acciones[1]]),
                    SizedBox(height: amplio ? 56 : 36),
                    const TituloSeccion('Lo último que se ha publicado'),
                    const SizedBox(height: 14),
                    Semantics(
                      container: true,
                      label: 'Filtrar por tipo',
                      child: amplio
                          ? Wrap(spacing: 8, runSpacing: 8, children: chips)
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              child: Row(
                                children: [
                                  for (final (i, chip) in chips.indexed) ...[if (i > 0) const SizedBox(width: 8), chip],
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _contenido(visibles, amplio),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(List<StoryPin> visibles, bool amplio) {
    if (_loading) return const Cargando();
    if (_sinConexion) return AvisoSinConexion(onRetry: reload);
    if (visibles.isEmpty) {
      final categoria = _category;
      if (categoria == null) {
        return Vacio(
          titulo: 'Todavía no hay ninguna historia',
          texto: 'Puedes ser la primera persona en dejar una.',
          icono: LucideIcons.searchX,
          accion: BotonPlaca(
            etiqueta: 'Dejar una historia',
            icono: LucideIcons.mic,
            tamano: TamanoBoton.medio,
            onPressed: widget.onLeaveStory,
          ),
        );
      }
      return Vacio(
        titulo: 'Todavía no hay ninguna ${categoryLabel(categoria).toLowerCase()}',
        texto: 'Puedes ser la primera persona en dejar una.',
        icono: LucideIcons.searchX,
        accion: BotonPlaca(
          etiqueta: 'Ver todas las historias',
          variante: VarianteBoton.secundario,
          tamano: TamanoBoton.medio,
          onPressed: () => setState(() => _category = null),
        ),
      );
    }
    final fichas = [
      for (final h in visibles) FichaHistoria.de(h, key: ValueKey(h.id), onTap: () => openStory(context, h)),
    ];
    if (!amplio) {
      return Column(
        children: [
          for (final (i, ficha) in fichas.indexed) ...[if (i > 0) const SizedBox(height: 14), ficha],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columna = (constraints.maxWidth - 24) / 2;
        return Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [for (final ficha in fichas) SizedBox(width: columna, child: ficha)],
        );
      },
    );
  }
}
