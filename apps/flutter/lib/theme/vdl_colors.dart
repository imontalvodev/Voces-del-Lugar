// lib/theme/vdl_colors.dart
import 'package:flutter/material.dart';

@immutable
class VdlColors extends ThemeExtension<VdlColors> {
  const VdlColors({
    required this.cal,
    required this.azulejo,
    required this.ficha,
    required this.tinta,
    required this.piedra,
    required this.filete,
    required this.anil,
    required this.anilHondo,
    required this.anilVelo,
    required this.ocre,
    required this.ocreTinta,
    required this.carmin,
    required this.verde,
    required this.sombraBoton,
    required this.sobreAnil,
    required this.sobreOcre,
    required this.sobreCarmin,
    required this.sombra,
    required this.scrim,
  });
  final Color cal,
      azulejo,
      ficha,
      tinta,
      piedra,
      filete,
      anil,
      anilHondo,
      anilVelo,
      ocre,
      ocreTinta,
      carmin,
      verde,
      sombraBoton;

  // No están en el handoff pero sí en el CSS del diseño (.vdl): el texto sobre
  // añil, ocre y carmín, la sombra sólida de las fichas y el velo de los diálogos.
  final Color sobreAnil, sobreOcre, sobreCarmin, sombra, scrim;

  static VdlColors of(BuildContext context) => Theme.of(context).extension<VdlColors>()!;

  static const claro = VdlColors(
    cal: Color(0xFFF5F6F3),
    azulejo: Color(0xFFFFFFFF),
    ficha: Color(0xFFF7F8F4),
    tinta: Color(0xFF1B1F2A),
    piedra: Color(0xFF5A6070),
    filete: Color(0xFFC9CDD6),
    anil: Color(0xFF2638A8),
    anilHondo: Color(0xFF18246E),
    anilVelo: Color(0xFFE6E9F7),
    ocre: Color(0xFFE0A22B),
    ocreTinta: Color(0xFF8A5A00),
    carmin: Color(0xFFA3203A),
    verde: Color(0xFF2F6B4F),
    sombraBoton: Color(0xFF18246E),
    sobreAnil: Color(0xFFFFFFFF),
    sobreOcre: Color(0xFF1B1F2A),
    sobreCarmin: Color(0xFFFFFFFF),
    sombra: Color(0xFFC9CDD6),
    scrim: Color(0x9E1B1F2A),
  );
  static const oscuro = VdlColors(
    cal: Color(0xFF11141C),
    azulejo: Color(0xFF1A1F2B),
    ficha: Color(0xFF161A24),
    tinta: Color(0xFFE9EBF2),
    piedra: Color(0xFFA9B0C2),
    filete: Color(0xFF343B4D),
    anil: Color(0xFF9DAAF2),
    anilHondo: Color(0xFFC3CBF7),
    anilVelo: Color(0xFF252C45),
    ocre: Color(0xFFF0B847),
    ocreTinta: Color(0xFFF0B847),
    carmin: Color(0xFFF08A9A),
    verde: Color(0xFF7CC4A0),
    sombraBoton: Color(0xFF05070B),
    sobreAnil: Color(0xFF11141C),
    sobreOcre: Color(0xFF11141C),
    sobreCarmin: Color(0xFF11141C),
    sombra: Color(0xFF0A0C11),
    scrim: Color(0xB3000000),
  );

  @override
  VdlColors copyWith() => this;
  @override
  VdlColors lerp(VdlColors? other, double t) => t < .5 ? this : (other ?? this);
}
