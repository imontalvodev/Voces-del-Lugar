import 'dart:async';

import 'package:flutter/foundation.dart';

/// Vale `true` mientras llegan avisos seguidos y vuelve a `false` cuando pasa
/// [pause] sin ninguno. Sirve para saber si algo se está moviendo ahora mismo.
class RecentActivity extends ValueNotifier<bool> {
  RecentActivity(this.pause) : super(false);

  final Duration pause;
  Timer? _timer;

  void ping() {
    _timer?.cancel();
    _timer = Timer(pause, () => value = false);
    value = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
