import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/theme/vdl_theme.dart';

// Matrices del handoff (fase 1, teselas raster): gris con un leve tinte añil en
// claro y gris invertido y enfriado hacia el añil en oscuro. Sin BackdropFilter.
const filtroClaro = ColorFilter.matrix(<double>[
  0.170, 0.572, 0.058, 0, 43, // R: gris + leve aclarado
  0.174, 0.587, 0.059, 0, 41, // G
  0.166, 0.558, 0.056, 0, 56, // B: algo más alto → tinte añil
  0, 0, 0, 1, 0,
]);
const filtroOscuro = ColorFilter.matrix(<double>[
  -0.149, -0.501, -0.051, 0, 204, // invierte el gris
  -0.145, -0.486, -0.049, 0, 206,
  -0.132, -0.444, -0.045, 0, 222, // y lo enfría hacia el añil
  0, 0, 0, 1, 0,
]);

ColorFilter filtroTeselas(Brightness brillo) => brillo == Brightness.dark ? filtroOscuro : filtroClaro;

/// Capa de teselas de OpenStreetMap con el filtro del tema activo.
TileLayer teselasVdl(BuildContext context) {
  final filtro = filtroTeselas(Theme.of(context).brightness);
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'org.vocesdellugar.app',
    tileBuilder: (context, tile, _) => ColorFiltered(colorFilter: filtro, child: tile),
  );
}

/// Atribución de OpenStreetMap, siempre visible abajo a la derecha.
class AtribucionOsm extends StatelessWidget {
  const AtribucionOsm({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: c.azulejo.withValues(alpha: 0.9),
        child: Text(
          '© colaboradores de OpenStreetMap',
          style: registro.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: c.tinta),
        ),
      ),
    );
  }
}
