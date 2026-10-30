import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/story_format.dart' as formato show contadaPor;
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/sello.dart';

/// Ficha de historia: pestaña con el número, datos a máquina y sello
/// opcional. Toda la ficha es un único botón.
class FichaHistoria extends StatelessWidget {
  const FichaHistoria({
    super.key,
    required this.titulo,
    required this.lugar,
    required this.categoria,
    required this.contadaPor,
    required this.onTap,
    this.numero,
    this.pueblo,
    this.epoca,
    this.duracionAudio,
    this.sello,
    this.compacta = false,
    this.extra,
  });

  /// La ficha de una historia de la API. Sin duración conocida, el audio
  /// se anuncia sin tiempo.
  factory FichaHistoria.de(
    StoryPin h, {
    Key? key,
    required VoidCallback? onTap,
    EstadoSello? sello,
    bool compacta = false,
    Widget? extra,
  }) {
    return FichaHistoria(
      key: key,
      numero: h.number,
      titulo: h.title,
      lugar: h.placeName,
      categoria: h.category,
      epoca: decadeLabel(h.decade),
      contadaPor: formato.contadaPor(h.narratorName, h.narratorRelation, deceased: h.narratorDeceased),
      duracionAudio: h.hasAudio ? (duracionCorta(h.audioSeconds) ?? '') : null,
      sello: sello,
      compacta: compacta,
      extra: extra,
      onTap: onTap,
    );
  }

  /// Número de ficha; sin él no hay pestaña (la API aún puede no darlo).
  final int? numero;
  final String titulo;
  final String lugar;
  final String? pueblo;
  final String categoria;
  final String? epoca;

  /// «Carmen Ruiz, abuela», sin el «Contada por».
  final String contadaPor;

  /// «4:12» si tiene audio; sin audio la ficha dice «Texto».
  final String? duracionAudio;
  final EstadoSello? sello;
  final bool compacta;
  final Widget? extra;
  final VoidCallback? onTap;

  String get _sitio => pueblo == null ? lugar : '$lugar · $pueblo';

  String get _leida => [
    if (numero != null) numeroFicha(numero!),
    titulo,
    if (sello != null) sello!.nombre,
    _sitio,
    [categoryLabel(categoria), ?epoca].join(', '),
    'Contada por $contadaPor',
    duracionAudio == null ? 'Texto' : (duracionAudio!.isEmpty ? 'Audio' : 'Audio, $duracionAudio'),
  ].join('. ');

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final texto = Theme.of(context).textTheme;
    final datos = registro.copyWith(fontSize: 16, height: 1.45, fontWeight: FontWeight.w400, color: c.tinta);
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloConSello(
          titulo: Text(
            titulo,
            style: texto.titleMedium!.copyWith(fontSize: compacta ? 19 : 21, color: c.tinta),
          ),
          sello: sello,
        ),
        const SizedBox(height: 8),
        Text(_sitio, style: datos.copyWith(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtiquetaTipo(categoria, color: c.piedra),
            if (epoca != null) Text('· $epoca', style: datos.copyWith(color: c.piedra)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text('Contada por $contadaPor', style: texto.bodySmall!.copyWith(color: c.piedra)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(duracionAudio == null ? LucideIcons.fileText : LucideIcons.audioLines, size: 18, color: c.anil),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    duracionAudio == null ? 'Texto' : (duracionAudio!.isEmpty ? 'Audio' : 'Audio · $duracionAudio'),
                    style: texto.bodySmall!.copyWith(color: c.anil, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
        ?extra,
      ],
    );
    return Padding(
      padding: EdgeInsets.only(top: numero == null ? 0 : 15),
      child: PlacaPulsable(
        key: const Key('ficha-caja'),
        onPressed: onTap,
        hunde: false,
        etiqueta: _leida,
        color: c.azulejo,
        borde: c.tinta,
        anchoBorde: 1.5,
        radio: 2,
        sombra: BoxShadow(color: c.sombra, offset: const Offset(3, 3)),
        alineacion: Alignment.topLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: compacta
                  ? EdgeInsets.fromLTRB(16, numero == null ? 16 : arribaConPestana(context, 16), 16, 14)
                  : EdgeInsets.fromLTRB(18, numero == null ? 20 : arribaConPestana(context, 20), 18, 16),
              child: ExcludeSemantics(child: contenido),
            ),
            if (numero != null)
              Positioned(
                top: -15,
                left: 16,
                child: ExcludeSemantics(
                  child: Container(
                    key: const Key('ficha-pestana'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.azulejo,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      border: Border(
                        top: BorderSide(color: c.tinta, width: 1.5),
                        left: BorderSide(color: c.tinta, width: 1.5),
                        right: BorderSide(color: c.tinta, width: 1.5),
                      ),
                    ),
                    child: Text(
                      numeroFicha(numero!),
                      style: registro.copyWith(fontSize: 15, height: 1.6, color: c.tinta),
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

/// Título a la izquierda y sello a la derecha; si no caben juntos (móvil
/// estrecho o letra muy grande), el sello sube encima del título.
class _TituloConSello extends StatelessWidget {
  const _TituloConSello({required this.titulo, required this.sello});

  final Widget titulo;
  final EstadoSello? sello;

  @override
  Widget build(BuildContext context) {
    final estado = sello;
    if (estado == null) return titulo;
    return LayoutBuilder(
      builder: (context, constraints) {
        final medida = TextPainter(
          text: TextSpan(text: estado.nombre.toUpperCase(), style: registro.copyWith(fontSize: 15, letterSpacing: 0.3)),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final anchoSello = medida.width + 16 + 6 + 16 + 4;
        medida.dispose();
        if (constraints.maxWidth - anchoSello - 12 >= 140) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titulo),
              const SizedBox(width: 12),
              Sello(estado),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Sello(estado), const SizedBox(height: 8), titulo],
        );
      },
    );
  }
}
