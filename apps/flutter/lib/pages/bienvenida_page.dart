import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voces/theme/letra.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';
import 'package:voces/ui/selector_letra.dart';

const _claveVista = 'bienvenida_vista';

/// La bienvenida solo sale la primera vez que se abre la app.
Future<bool> bienvenidaVista() async => (await SharedPreferences.getInstance()).getBool(_claveVista) ?? false;

Future<void> marcarBienvenidaVista() async => (await SharedPreferences.getInstance()).setBool(_claveVista, true);

class BienvenidaPage extends StatelessWidget {
  const BienvenidaPage({super.key, required this.letra, required this.onEmpezar});

  final PreferenciaLetra letra;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: MargenPagina(
            ancho: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Marca(),
                const SizedBox(height: 22),
                const TituloPantalla('Las historias de cada sitio, contadas por quien las vivió.', grande: true),
                const SizedBox(height: 2),
                const Entradilla('Escucha lo que pasó en tu pueblo o barrio, y deja lo que te contaron a ti.'),
                const SizedBox(height: 26),
                SelectorLetra(preferencia: letra),
                Text(
                  'Puedes cambiarlo cuando quieras en Cuenta.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: c.piedra),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BarraAcciones(
        children: [
          BotonPlaca(
            etiqueta: 'Empezar',
            expandir: true,
            onPressed: () async {
              await marcarBienvenidaVista();
              onEmpezar();
            },
          ),
        ],
      ),
    );
  }
}
