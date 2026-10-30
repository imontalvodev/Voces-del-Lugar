import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/placa.dart';

/// Puntos de ruptura del handoff.
enum Vdl { compacto, medio, amplio }

Vdl tamano(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < 600 ? Vdl.compacto : (w < 1024 ? Vdl.medio : Vdl.amplio);
}

/// La marca: una placa con el punto ocre y el nombre.
class Marca extends StatelessWidget {
  const Marca({super.key, this.pequena = false});

  final bool pequena;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Semantics(
      label: 'Voces del Lugar',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: c.azulejo,
          border: Border.all(color: c.anil, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          padding: pequena
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: c.anil)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c.ocre, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Voces del Lugar',
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(fontSize: pequena ? 16 : 18, height: 1.1, fontWeight: FontWeight.w800, color: c.anil),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de pantalla: 28 en móvil y 34 en escritorio; el de portada, 32 y 44.
class TituloPantalla extends StatelessWidget {
  const TituloPantalla(this.texto, {super.key, this.grande = false});

  final String texto;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final amplio = tamano(context) == Vdl.amplio;
    final size = grande ? (amplio ? 44.0 : 32.0) : (amplio ? 34.0 : 28.0);
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: size, letterSpacing: -0.2),
      ),
    );
  }
}

/// Encabezado de sección (23).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, child: Text(texto, style: Theme.of(context).textTheme.titleLarge));
  }
}

/// Texto de apoyo bajo un título, en piedra.
class Entradilla extends StatelessWidget {
  const Entradilla(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: VdlColors.of(context).piedra),
        ),
      ),
    );
  }
}

/// Márgenes de página: 16 en móvil, 24 en tableta y 48 en escritorio, con un
/// ancho máximo para que las líneas no se alarguen.
class MargenPagina extends StatelessWidget {
  const MargenPagina({super.key, required this.child, this.ancho = 1180});

  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final padding = switch (tamano(context)) {
      Vdl.compacto => const EdgeInsets.fromLTRB(16, 20, 16, 32),
      Vdl.medio => const EdgeInsets.fromLTRB(24, 28, 24, 40),
      Vdl.amplio => const EdgeInsets.fromLTRB(48, 40, 48, 64),
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Barra de acciones fija abajo: los botones dicen el siguiente paso.
class BarraAcciones extends StatelessWidget {
  const BarraAcciones({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border(top: BorderSide(color: c.tinta, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Row(
                children: [
                  for (final (i, hijo) in children.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: hijo),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «No hay conexión» con la forma de volver a intentarlo.
class AvisoSinConexion extends StatelessWidget {
  const AvisoSinConexion({super.key, required this.onRetry, this.texto});

  final VoidCallback onRetry;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Aviso(
      tono: TonoAviso.error,
      titulo: 'No hay conexión',
      texto: texto ?? 'No hemos podido cargar las historias. Revisa el wifi o los datos y vuelve a intentarlo.',
      accion: BotonPlaca(
        etiqueta: 'Volver a intentarlo',
        icono: LucideIcons.wifiOff,
        variante: VarianteBoton.secundario,
        tamano: TamanoBoton.medio,
        onPressed: onRetry,
      ),
    );
  }
}

/// «Tu sesión ha caducado» con la forma de volver a entrar.
class AvisoSesionCaducada extends StatelessWidget {
  const AvisoSesionCaducada({super.key, required this.onEntrar});

  final VoidCallback onEntrar;

  @override
  Widget build(BuildContext context) {
    return Aviso(
      tono: TonoAviso.aviso,
      titulo: 'Tu sesión ha caducado',
      texto: 'Entra otra vez. Lo que estabas haciendo sigue guardado.',
      accion: BotonPlaca(etiqueta: 'Entrar otra vez', tamano: TamanoBoton.medio, onPressed: onEntrar),
    );
  }
}
