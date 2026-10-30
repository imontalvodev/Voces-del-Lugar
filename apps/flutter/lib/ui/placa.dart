import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';

/// Curva y duración del «hundido» al pulsar (press: 120 ms).
const curvaVdl = Cubic(0.2, 0, 0, 1);
const duracionPulsar = Duration(milliseconds: 120);

Duration duracion(BuildContext context, Duration valor) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : valor;

/// Base de todo lo que se pulsa en la app: borde, sombra sólida desplazada y,
/// al pulsar, se hunde 2 px y pierde la sombra. Sin onda. Con teclado se ve el
/// anillo de foco (añil hondo y ocre).
class PlacaPulsable extends StatefulWidget {
  const PlacaPulsable({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.borde,
    this.anchoBorde = 2,
    this.sombra,
    this.radio = 4,
    this.padding = EdgeInsets.zero,
    this.minimo = const Size(48, 48),
    this.etiqueta,
    this.seleccionado,
    this.alineacion = Alignment.center,
    this.hunde = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? borde;
  final double anchoBorde;

  /// Sombra sólida, si la lleva. Al pulsar desaparece.
  final BoxShadow? sombra;
  final double radio;
  final EdgeInsetsGeometry padding;
  final Size minimo;

  /// Nombre para el lector de pantalla cuando el contenido no lo dice.
  final String? etiqueta;
  final bool? seleccionado;
  final AlignmentGeometry alineacion;

  /// Las fichas son botones enteros pero no se hunden al pulsarlas.
  final bool hunde;

  @override
  State<PlacaPulsable> createState() => _PlacaPulsableState();
}

class _PlacaPulsableState extends State<PlacaPulsable> {
  var _pulsado = false;
  var _foco = false;

  bool get _activo => widget.onPressed != null;

  void _hundir(bool valor) {
    if (_pulsado != valor && mounted) setState(() => _pulsado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final hundido = _pulsado && _activo && widget.hunde;
    final borde = widget.borde;
    final sombra = widget.sombra;
    final forma = BorderRadius.circular(widget.radio);
    return Semantics(
      container: true,
      button: true,
      enabled: _activo,
      selected: widget.seleccionado,
      label: widget.etiqueta,
      child: FocusableActionDetector(
        enabled: _activo,
        mouseCursor: _activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (valor) => setState(() => _foco = valor),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: _activo ? (_) => _hundir(true) : null,
          onPointerUp: (_) => _hundir(false),
          onPointerCancel: (_) => _hundir(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapCancel: () => _hundir(false),
            excludeFromSemantics: !_activo,
            child: CustomPaint(
              foregroundPainter: _foco ? _AnilloFoco(c, widget.radio) : null,
              child: AnimatedContainer(
                duration: duracion(context, duracionPulsar),
                curve: curvaVdl,
                transform: Matrix4.translationValues(hundido ? 2 : 0, hundido ? 2 : 0, 0),
                constraints: BoxConstraints(minWidth: widget.minimo.width, minHeight: widget.minimo.height),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.color,
                  border: borde == null ? null : Border.all(color: borde, width: widget.anchoBorde),
                  borderRadius: forma,
                  boxShadow: [if (sombra != null && !hundido) sombra],
                ),
                child: Align(alignment: widget.alineacion, widthFactor: 1, heightFactor: 1, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo de foco del diseño: 3 px añil hondo a 2 px del borde y ocre por fuera.
class _AnilloFoco extends CustomPainter {
  _AnilloFoco(this.c, this.radio);

  final VdlColors c;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final caja = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radio));
    canvas.drawRRect(
      caja.inflate(6.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = c.ocre,
    );
    canvas.drawRRect(
      caja.inflate(3.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c.anilHondo,
    );
  }

  @override
  bool shouldRepaint(_AnilloFoco old) => old.c != c || old.radio != radio;
}

enum VarianteBoton { principal, secundario, peligro, peligroBorde }

enum TamanoBoton {
  grande(56, 22, 18),
  medio(48, 16, 16);

  const TamanoBoton(this.alto, this.padding, this.letra);

  final double alto;
  final double padding;
  final double letra;
}

/// Botón placa: principal, secundario o de peligro. Deshabilitado y cargando
/// conservan el texto.
class BotonPlaca extends StatelessWidget {
  const BotonPlaca({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.variante = VarianteBoton.principal,
    this.tamano = TamanoBoton.grande,
    this.icono,
    this.cargando,
    this.expandir = false,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final VarianteBoton variante;
  final TamanoBoton tamano;
  final IconData? icono;

  /// Texto mientras se hace lo que el botón pide, por ejemplo «Guardando…».
  final String? cargando;
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final activo = onPressed != null && cargando == null;
    final (fondo, texto, borde, sombra) = !activo
        ? (c.filete, c.piedra, c.filete, false)
        : switch (variante) {
            VarianteBoton.principal => (c.anil, c.sobreAnil, c.anil, true),
            VarianteBoton.secundario => (c.azulejo, c.anil, c.anil, true),
            VarianteBoton.peligro => (c.carmin, c.sobreCarmin, c.carmin, true),
            VarianteBoton.peligroBorde => (c.azulejo, c.carmin, c.carmin, false),
          };
    final icon = cargando != null ? LucideIcons.hourglass : icono;
    final estilo = Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: tamano.letra, height: 1.2, color: texto);
    final contenido = Row(
      mainAxisSize: expandir ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: texto), const SizedBox(width: 10)],
        Flexible(
          child: Text(cargando ?? etiqueta, textAlign: TextAlign.center, style: estilo),
        ),
      ],
    );
    return PlacaPulsable(
      onPressed: activo ? onPressed : null,
      color: fondo,
      borde: borde,
      sombra: sombra ? BoxShadow(color: c.sombraBoton, offset: const Offset(2, 2)) : null,
      minimo: Size(expandir ? double.infinity : 48, tamano.alto),
      padding: EdgeInsets.symmetric(horizontal: tamano.padding, vertical: 8),
      child: contenido,
    );
  }
}

/// Enlace discreto: texto añil subrayado, con zona de toque de 48.
class EnlaceDiscreto extends StatelessWidget {
  const EnlaceDiscreto({super.key, required this.etiqueta, required this.onPressed, this.icono, this.color});

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final tinta = onPressed == null ? c.piedra : (color ?? c.anil);
    final estilo = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 16,
      height: 1.2,
      color: tinta,
      decoration: TextDecoration.underline,
      decorationColor: tinta,
      decorationThickness: 2,
    );
    return PlacaPulsable(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 18, color: tinta), const SizedBox(width: 6)],
          Flexible(child: Text(etiqueta, style: estilo)),
        ],
      ),
    );
  }
}

/// Botón cuadrado con borde de tinta para acciones con icono (cerrar, ±10 s…).
class BotonCuadrado extends StatelessWidget {
  const BotonCuadrado({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.icono,
    this.child,
    this.lado = 48,
  }) : assert(icono != null || child != null);

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Widget? child;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Tooltip(
      message: etiqueta,
      excludeFromSemantics: true,
      child: PlacaPulsable(
        onPressed: onPressed,
        etiqueta: etiqueta,
        color: c.azulejo,
        borde: onPressed == null ? c.filete : c.tinta,
        minimo: Size(lado, lado),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IconTheme.merge(
          data: IconThemeData(color: onPressed == null ? c.piedra : c.tinta, size: 22),
          child: child ?? Icon(icono),
        ),
      ),
    );
  }
}
