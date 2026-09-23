import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Teselas de OpenStreetMap pasadas a crepúsculo: se invierte la luminancia
/// (el fondo claro queda índigo y los rótulos oscuros quedan claros) y se tiñe
/// hacia el violeta. No necesita clave de ningún proveedor.
TileLayer duskTiles() {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'dev.vocesdellugar.voces',
    tileBuilder: (context, tile, _) => ColorFiltered(colorFilter: _dusk, child: tile),
  );
}

const _r = 0.52;
const _g = 0.4;
const _b = 0.74;

const _dusk = ColorFilter.matrix([
  -0.2126 * _r, -0.7152 * _r, -0.0722 * _r, 0, 22 + 255 * _r, //
  -0.2126 * _g, -0.7152 * _g, -0.0722 * _g, 0, 16 + 255 * _g,
  -0.2126 * _b, -0.7152 * _b, -0.0722 * _b, 0, 40 + 255 * _b,
  0, 0, 0, 1, 0,
]);
