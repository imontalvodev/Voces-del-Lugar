import 'package:flutter/widgets.dart';
import 'package:voces/ui/recent_activity.dart';

/// Avisa a los cristales (`Glass`) de que algo se está moviendo detrás, para que
/// no desenfoquen el fondo en cada fotograma: es lo más caro de pintar. Pasada
/// una breve pausa sin avisos vuelven a desenfocar.
class BlurGate extends StatefulWidget {
  const BlurGate({super.key, required this.child});

  final Widget child;

  /// El interruptor del `BlurGate` más cercano, para avisar de movimiento.
  static RecentActivity of(BuildContext context) => context.getInheritedWidgetOfExactType<_Gate>()!.notifier!;

  /// Si hay que saltarse el desenfoque ahora mismo. Sin `BlurGate` arriba, no.
  static bool suspended(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Gate>()?.notifier?.value ?? false;

  @override
  State<BlurGate> createState() => _BlurGateState();
}

class _BlurGateState extends State<BlurGate> {
  final _moving = RecentActivity(const Duration(milliseconds: 180));

  @override
  void dispose() {
    _moving.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Gate(notifier: _moving, child: widget.child);
}

class _Gate extends InheritedNotifier<RecentActivity> {
  const _Gate({required RecentActivity super.notifier, required super.child});
}
