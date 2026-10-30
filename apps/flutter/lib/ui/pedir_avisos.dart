import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/avisos_push.dart';
import 'package:voces/permisos.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/placa.dart';

/// Nombres de las apps de avisos más comunes; las demás, por su paquete.
const _apps = {
  'io.heckel.ntfy': 'ntfy',
  'org.unifiedpush.distributor.nextpush': 'NextPush',
  'org.unifiedpush.distributor.fcm': 'FCM Distributor',
  'eu.siacs.conversations': 'Conversations',
  'im.molly.app': 'Molly',
};

/// Pide los avisos y explica lo que haga falta si no se puede. Devuelve si
/// quedaron activados.
Future<bool> pedirAvisos(BuildContext context, AvisosPush avisos) async {
  final resultado = await avisos.activar(elegir: (lista) => _elegirApp(context, lista));
  if (!context.mounted) return resultado == ResultadoAvisos.activados;
  switch (resultado) {
    case ResultadoAvisos.activados:
      mostrarNotificacion(context, 'Listo. Te avisaremos en este móvil.');
    case ResultadoAvisos.sinPermiso:
      mostrarNotificacion(
        context,
        'Sin permiso para avisos no podemos avisarte. Puedes darlo en Ajustes.',
        error: true,
        accion: 'Abrir Ajustes',
        onAccion: abrirAjustesApp,
      );
    case ResultadoAvisos.sinDistribuidor:
      await showDialog<void>(
        context: context,
        builder: (context) => DialogoVdl(
          titulo: 'Falta una app de avisos',
          acciones: [BotonPlaca(etiqueta: 'Entendido', expandir: true, onPressed: () => Navigator.pop(context))],
          child: Text(
            'Voces del Lugar avisa sin pasar por Google. Para eso hace falta en el móvil una app de '
            'avisos, como ntfy, que es gratuita. Instálala y vuelve a pedir los avisos.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 17),
          ),
        ),
      );
    case ResultadoAvisos.fallo:
      mostrarNotificacion(
        context,
        'No se han podido activar los avisos. Revisa la conexión y vuelve a intentarlo.',
        error: true,
      );
  }
  return resultado == ResultadoAvisos.activados;
}

Future<String?> _elegirApp(BuildContext context, List<String> distribuidores) {
  return showDialog<String>(
    context: context,
    builder: (context) => DialogoVdl(
      titulo: '¿Con qué app recibes los avisos?',
      acciones: [
        for (final paquete in distribuidores)
          BotonPlaca(
            etiqueta: _apps[paquete] ?? paquete,
            variante: VarianteBoton.secundario,
            expandir: true,
            onPressed: () => Navigator.pop(context, paquete),
          ),
        EnlaceDiscreto(etiqueta: 'Cancelar', onPressed: () => Navigator.pop(context)),
      ],
      child: Text(
        'Tienes varias apps que pueden recibirlos. Elige una.',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 17),
      ),
    ),
  );
}

/// Al terminar de contar, si la historia espera revisión: «¿Te avisamos
/// cuando se publique?». Solo sale si hay avisos en esta plataforma y aún no
/// se han pedido.
class PreguntaAvisos extends StatefulWidget {
  const PreguntaAvisos({super.key, required this.avisos});

  final AvisosPush avisos;

  @override
  State<PreguntaAvisos> createState() => _PreguntaAvisosState();
}

class _PreguntaAvisosState extends State<PreguntaAvisos> {
  var _descartada = false;
  var _pidiendo = false;

  Future<void> _si() async {
    setState(() => _pidiendo = true);
    await pedirAvisos(context, widget.avisos);
    if (mounted) setState(() => _pidiendo = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.avisos.activos,
      builder: (context, activos, _) {
        if (activos || _descartada || !widget.avisos.disponible) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Aviso(
            tono: TonoAviso.info,
            titulo: '¿Te avisamos cuando se publique?',
            texto: 'Te llegará un aviso a este móvil cuando esté en el mapa, o si no se publica.',
            accion: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BotonPlaca(
                  etiqueta: 'Sí, avísame',
                  icono: LucideIcons.bell,
                  tamano: TamanoBoton.medio,
                  cargando: _pidiendo ? 'Activando…' : null,
                  onPressed: _si,
                ),
                EnlaceDiscreto(etiqueta: 'Ahora no', onPressed: () => setState(() => _descartada = true)),
              ],
            ),
          ),
        );
      },
    );
  }
}
