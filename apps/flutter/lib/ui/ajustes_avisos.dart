import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/avisos_push.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/campos.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/pedir_avisos.dart';
import 'package:voces/ui/placa.dart';

/// Radio a la redonda dicho para leer: «2 km», «500 m».
String radioLegible(int metros) =>
    metros >= 1000 ? '${(metros / 1000).toStringAsFixed(metros % 1000 == 0 ? 0 : 1).replaceAll('.', ',')} km' : '$metros m';

/// Cuenta › Avisos: pedirlos, qué avisos llegan y los sitios vigilados.
class AjustesAvisos extends StatefulWidget {
  const AjustesAvisos({super.key, required this.api, required this.avisos});

  final VocesApi api;
  final AvisosPush avisos;

  @override
  State<AjustesAvisos> createState() => _AjustesAvisosState();
}

class _AjustesAvisosState extends State<AjustesAvisos> {
  PrefsAvisos? _prefs;
  List<SitioVigilado> _sitios = [];
  var _sinConexion = false;

  @override
  void initState() {
    super.initState();
    widget.avisos.activos.addListener(_cargar);
    widget.api.changes.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    widget.avisos.activos.removeListener(_cargar);
    widget.api.changes.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!widget.avisos.activos.value || widget.api.account == null) return;
    try {
      final (prefs, sitios) = await (widget.api.pushPrefs(), widget.api.watchedPlaces()).wait;
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _sitios = sitios;
          _sinConexion = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sinConexion = true);
    }
  }

  Future<void> _cambiar({bool? lomio, bool? porRevisar}) async {
    try {
      final prefs = await widget.api.updatePushPrefs(lomio: lomio, porRevisar: porRevisar);
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {
      if (mounted) mostrarNotificacion(context, 'No se ha podido guardar. Revisa la conexión.', error: true);
    }
  }

  Future<void> _olvidar(SitioVigilado sitio) async {
    try {
      await widget.api.unwatchPlace(sitio.id);
      if (!mounted) return;
      setState(() => _sitios = [..._sitios]..remove(sitio));
      mostrarNotificacion(context, 'Ya no te avisaremos de ${sitio.nombre}.');
    } catch (_) {
      if (mounted) mostrarNotificacion(context, 'No se ha podido quitar. Revisa la conexión.', error: true);
    }
  }

  Future<void> _dejar() async {
    final seguro = await confirmar(
      context,
      titulo: '¿Dejar de recibir avisos?',
      mensaje: 'Este móvil no recibirá más avisos. Tus sitios vigilados se quedan por si vuelves a pedirlos.',
      si: 'Sí, dejar de recibirlos',
    );
    if (!seguro) return;
    await widget.avisos.desactivar();
    if (mounted) mostrarNotificacion(context, 'Hecho. No te llegarán más avisos a este móvil.');
  }

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border.all(color: c.tinta, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.avisos.activos,
        builder: (context, activos, _) {
          if (!activos) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloSeccion('Avisos'),
                const SizedBox(height: 8),
                Text(
                  'Te avisamos cuando se publique lo que dejas, cuando haya algo por revisar o cuando '
                  'aparezca una historia cerca de un sitio que vigiles.',
                  style: letra.bodySmall!.copyWith(color: c.piedra),
                ),
                const SizedBox(height: 14),
                BotonPlaca(
                  etiqueta: 'Recibir avisos en este móvil',
                  icono: LucideIcons.bell,
                  tamano: TamanoBoton.medio,
                  expandir: true,
                  onPressed: () => pedirAvisos(context, widget.avisos),
                ),
              ],
            );
          }
          final prefs = _prefs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TituloSeccion('Avisos'),
              const SizedBox(height: 10),
              if (_sinConexion)
                AvisoSinConexion(onRetry: _cargar)
              else if (prefs != null) ...[
                Casilla(
                  marcada: prefs.lomio,
                  etiqueta: 'Cuando se publique o se rechace lo que dejo',
                  onChanged: (v) => _cambiar(lomio: v),
                ),
                if (widget.api.account?.canModerate ?? false) ...[
                  const SizedBox(height: 8),
                  Casilla(
                    marcada: prefs.porRevisar,
                    etiqueta: 'Cuando haya historias por revisar',
                    onChanged: (v) => _cambiar(porRevisar: v),
                  ),
                ],
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Sitios que vigilas',
                    style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                if (_sitios.isEmpty)
                  Text(
                    'Aún no vigilas ningún sitio. En la ficha de una historia, pulsa «Avisarme de lo nuevo aquí».',
                    style: letra.bodySmall!.copyWith(color: c.piedra),
                  )
                else
                  for (final sitio in _sitios)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.filete, width: 1.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sitio.nombre, style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${radioLegible(sitio.radio)} a la redonda',
                                  style: registro.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: c.piedra),
                                ),
                              ],
                            ),
                          ),
                          BotonCuadrado(
                            icono: LucideIcons.x,
                            etiqueta: 'Dejar de vigilar ${sitio.nombre}',
                            onPressed: () => _olvidar(sitio),
                          ),
                        ],
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: EnlaceDiscreto(
                  etiqueta: 'Dejar de recibir avisos',
                  icono: LucideIcons.bellOff,
                  onPressed: _dejar,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
