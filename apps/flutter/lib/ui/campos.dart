import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

/// Mensaje de error con icono y texto en carmín, nunca solo color.
class MensajeError extends StatelessWidget {
  const MensajeError(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 20, color: c.carmin),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.carmin, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo con la etiqueta siempre visible, la ayuda debajo de ella y el error
/// con icono y texto.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.ayuda,
    this.error,
    this.controller,
    this.opcional = false,
    this.lineas = 1,
    this.ocultar = false,
    this.teclado,
    this.accion,
    this.autorrelleno,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.habilitado = true,
    this.soloLectura = false,
    this.maximo,
    this.mayusculas = TextCapitalization.sentences,
  });

  final String etiqueta;
  final String? ayuda;
  final String? error;
  final TextEditingController? controller;
  final bool opcional;

  /// Líneas visibles: 1 para una línea; más para un texto largo que crece.
  final int lineas;
  final bool ocultar;
  final TextInputType? teclado;
  final TextInputAction? accion;
  final Iterable<String>? autorrelleno;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool habilitado;
  final bool soloLectura;
  final int? maximo;
  final TextCapitalization mayusculas;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final texto = Theme.of(context).textTheme;
    final hayError = error != null && error!.isNotEmpty;
    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: color, width: ancho),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: etiqueta,
                  children: [
                    if (opcional)
                      TextSpan(
                        text: ' (opcional)',
                        style: TextStyle(fontWeight: FontWeight.w400, color: c.piedra),
                      ),
                  ],
                ),
                style: texto.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 6),
              if (ayuda != null) ...[
                Text(ayuda!, style: texto.bodySmall!.copyWith(color: c.piedra)),
                const SizedBox(height: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: habilitado,
                  readOnly: soloLectura,
                  obscureText: ocultar,
                  keyboardType: teclado ?? (lineas > 1 ? TextInputType.multiline : null),
                  textInputAction: accion,
                  autofillHints: autorrelleno,
                  textCapitalization: ocultar ? TextCapitalization.none : mayusculas,
                  minLines: lineas,
                  maxLines: lineas == 1 ? 1 : null,
                  maxLength: maximo,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  cursorColor: c.anilHondo,
                  style: texto.bodyMedium!.copyWith(color: c.tinta),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: habilitado ? c.azulejo : c.ficha,
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: borde(hayError ? c.carmin : c.tinta, 2),
                    disabledBorder: borde(c.filete, 2),
                    focusedBorder: borde(hayError ? c.carmin : c.anilHondo, 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hayError) ...[const SizedBox(height: 8), MensajeError(error!)],
      ],
    );
  }
}

/// Zona que se pulsa con teclado o con el dedo y no se hunde (casillas y
/// opciones): el estado lo dice la propia caja.
class _Marcable extends StatelessWidget {
  const _Marcable({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: onTap != null,
      mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }
}

/// Casilla de 28 px dentro de una fila de al menos 48 de toque.
class Casilla extends StatelessWidget {
  const Casilla({
    super.key,
    required this.marcada,
    required this.etiqueta,
    required this.onChanged,
    this.descripcion,
    this.error,
  });

  final bool marcada;
  final String etiqueta;
  final String? descripcion;
  final String? error;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final texto = Theme.of(context).textTheme;
    final hayError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          checked: marcada,
          enabled: onChanged != null,
          label: etiqueta,
          hint: descripcion,
          child: _Marcable(
            onTap: onChanged == null ? null : () => onChanged!(!marcada),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const Key('casilla-caja'),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: marcada ? c.anil : c.azulejo,
                        border: Border.all(color: hayError ? c.carmin : c.tinta, width: 2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: marcada ? Icon(LucideIcons.check, size: 20, color: c.sobreAnil) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              etiqueta,
                              style: texto.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
                            ),
                            if (descripcion != null)
                              Text(descripcion!, style: texto.bodySmall!.copyWith(color: c.piedra)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hayError) Padding(padding: const EdgeInsets.only(left: 42), child: MensajeError(error!)),
      ],
    );
  }
}

/// Una licencia explicada en lenguaje llano, para elegir entre varias.
class OpcionLicencia extends StatelessWidget {
  const OpcionLicencia({
    super.key,
    required this.elegida,
    required this.titulo,
    required this.descripcion,
    required this.onSelected,
    this.sigla,
  });

  final bool elegida;
  final String titulo;

  /// «CC BY-SA 4.0», escrita a máquina junto al título.
  final String? sigla;
  final String descripcion;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final texto = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: elegida,
      label: sigla == null ? titulo : '$titulo, $sigla',
      hint: descripcion,
      child: _Marcable(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: elegida ? c.anilVelo : c.azulejo,
            border: Border.all(color: elegida ? c.anil : c.filete, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.azulejo,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.tinta, width: 2),
                  ),
                  child: elegida
                      ? Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: c.anil, shape: BoxShape.circle),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: titulo,
                          children: [
                            if (sigla != null)
                              TextSpan(
                                text: ' · $sigla',
                                style: registro.copyWith(fontSize: 16, color: c.piedra),
                              ),
                          ],
                        ),
                        style: texto.bodyMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.3),
                      ),
                      const SizedBox(height: 2),
                      Text(descripcion, style: texto.bodySmall!.copyWith(color: c.piedra)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
