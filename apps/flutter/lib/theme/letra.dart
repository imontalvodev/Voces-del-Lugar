import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajuste propio de la app («¿Cómo lees mejor?»), que se suma al del sistema.
enum TamanoLetra {
  normal(1.0, 'Normal'),
  grande(1.2, 'Grande'),
  muyGrande(1.4, 'Muy grande');

  const TamanoLetra(this.escala, this.nombre);

  final double escala;
  final String nombre;
}

/// Tamaño de letra elegido, guardado en el dispositivo.
class PreferenciaLetra extends ValueNotifier<TamanoLetra> {
  PreferenciaLetra(super.value);

  static const _clave = 'tamano_letra';

  static Future<PreferenciaLetra> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    final tamano = TamanoLetra.values.where((t) => t.name == guardado).firstOrNull;
    return PreferenciaLetra(tamano ?? TamanoLetra.normal);
  }

  Future<void> elegir(TamanoLetra tamano) async {
    value = tamano;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, tamano.name);
  }

  static PreferenciaLetra of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LetraScope>();
    assert(scope != null, 'Falta EscalaLetra por encima');
    return scope!.notifier!;
  }
}

/// Aplica el ajuste a todo lo que cuelga de aquí: respeta el tamaño del
/// sistema y lo multiplica por el elegido en la app.
class EscalaLetra extends StatelessWidget {
  const EscalaLetra({super.key, required this.preferencia, required this.child});

  final PreferenciaLetra preferencia;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TamanoLetra>(
      valueListenable: preferencia,
      child: child,
      builder: (context, tamano, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * tamano.escala)),
          child: _LetraScope(notifier: preferencia, child: child!),
        );
      },
    );
  }
}

class _LetraScope extends InheritedNotifier<PreferenciaLetra> {
  const _LetraScope({required super.notifier, required super.child});
}
