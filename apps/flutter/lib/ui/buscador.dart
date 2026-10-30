import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/placa.dart';

/// Buscador de pueblos, barrios y calles: busca mientras se escribe (desde
/// tres letras) y enseña los lugares encontrados debajo.
class BuscadorLugares extends StatefulWidget {
  const BuscadorLugares({super.key, required this.api, required this.onLugar});

  final VocesApi api;
  final ValueChanged<PlaceHit> onLugar;

  @override
  State<BuscadorLugares> createState() => _BuscadorLugaresState();
}

class _BuscadorLugaresState extends State<BuscadorLugares> {
  final _texto = TextEditingController();
  Timer? _espera;
  List<PlaceHit> _lugares = [];
  bool _buscando = false;
  int _ticket = 0;

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _cambio(String valor) {
    _espera?.cancel();
    final consulta = valor.trim();
    final ticket = ++_ticket;
    if (consulta.length < 3) {
      setState(() {
        _lugares = [];
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _espera = Timer(const Duration(milliseconds: 450), () async {
      List<PlaceHit> encontrados;
      try {
        encontrados = await widget.api.searchPlaces(consulta);
      } catch (_) {
        encontrados = [];
      }
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _lugares = encontrados;
        _buscando = false;
      });
    });
  }

  void _elegir(PlaceHit lugar) {
    _ticket++;
    _texto.text = lugar.name;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _lugares = [];
      _buscando = false;
    });
    widget.onLugar(lugar);
  }

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final campo = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.azulejo,
        border: Border.all(color: c.tinta, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 22, color: c.tinta),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: 'Buscar un pueblo, barrio o calle',
              textField: true,
              child: TextField(
                controller: _texto,
                onChanged: _cambio,
                onSubmitted: (_) {
                  if (_lugares.isNotEmpty) _elegir(_lugares.first);
                },
                textInputAction: TextInputAction.search,
                cursorColor: c.anilHondo,
                style: letra.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Busca un pueblo, barrio o calle',
                  hintStyle: letra.bodyMedium!.copyWith(color: c.piedra),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!_buscando && _lugares.isEmpty) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        campo,
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: c.azulejo,
            border: Border.all(color: c.tinta, width: 2),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: c.sombra, offset: const Offset(3, 3))],
          ),
          child: Semantics(
            container: true,
            label: 'Lugares encontrados',
            child: _buscando
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Buscando lugares…',
                      style: letra.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: c.piedra),
                    ),
                  )
                : Column(
                    children: [
                      for (final (i, lugar) in _lugares.indexed)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == 0 ? c.anilVelo : null,
                            border: i == 0 ? null : Border(top: BorderSide(color: c.filete, width: 1.5)),
                          ),
                          child: PlacaPulsable(
                            onPressed: () => _elegir(lugar),
                            hunde: false,
                            radio: 0,
                            minimo: const Size(48, 60),
                            alineacion: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lugar.name,
                                  style: letra.bodyMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                                if (lugar.context.isNotEmpty || lugar.kindLabel.isNotEmpty)
                                  Text(
                                    [
                                      if (lugar.kindLabel.isNotEmpty) lugar.kindLabel,
                                      if (lugar.context.isNotEmpty) lugar.context,
                                    ].join(' · '),
                                    style: letra.bodySmall!.copyWith(color: c.piedra),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
