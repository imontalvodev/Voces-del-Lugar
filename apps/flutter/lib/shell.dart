import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/compose_page.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/tokens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api});

  final VocesApi api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  LatLng? _pendingPoint;
  final _homeKey = GlobalKey<HomePageState>();
  final _mapKey = GlobalKey<MapPageState>();
  final _accountKey = GlobalKey<AccountPageState>();

  void _choosePointOnMap() {
    setState(() => _index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mapKey.currentState?.beginPlacing());
  }

  Future<void> _leaveStory(LatLng point) async {
    if (widget.api.account == null) {
      _pendingPoint = point;
      setState(() => _index = 2);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entra o crea una cuenta y seguimos con la historia de ese sitio.')));
      return;
    }
    _pendingPoint = null;
    final created = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        transitionDuration: Motion.of(context, const Duration(milliseconds: 520)),
        reverseTransitionDuration: Motion.of(context, const Duration(milliseconds: 360)),
        pageBuilder: (_, _, _) => ComposePage(api: widget.api, point: point),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Motion.out, reverseCurve: Curves.easeIn);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (created == true) {
      _homeKey.currentState?.reload();
      _mapKey.currentState?.reload();
      _accountKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(key: _homeKey, api: widget.api, onLeaveStory: _choosePointOnMap, onOpenMap: () => setState(() => _index = 1)),
      MapPage(key: _mapKey, api: widget.api, onLeaveStory: _leaveStory),
      AccountPage(
        key: _accountKey,
        api: widget.api,
        onLeaveStory: _choosePointOnMap,
        onChanged: () {
          setState(() {});
          final pending = _pendingPoint;
          if (pending != null && widget.api.account != null) _leaveStory(pending);
        },
      ),
    ];
    return Scaffold(
      backgroundColor: Palette.night,
      body: Sky(
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    _Reveal(
                      active: i == _index,
                      child: TickerMode(enabled: i == _index, child: pages[i]),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: _Dock(index: _index, onSelect: (i) => setState(() => _index = i)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Al volver a una pestaña, entra con un fundido corto; el estado se conserva.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _Reveal old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Motion.out);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: widget.child),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _itemWidth = 92.0;
  static const _items = [
    ('Inicio', LucideIcons.house, LucideIcons.house),
    ('Mapa', LucideIcons.map, LucideIcons.map),
    ('Cuenta', LucideIcons.circleUser, LucideIcons.circleUser),
  ];

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 999,
      tint: Palette.glassStrong.withValues(alpha: 0.72),
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: _itemWidth * _items.length,
        height: 60,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Motion.of(context, const Duration(milliseconds: 520)),
              curve: Curves.easeOutBack,
              left: index * _itemWidth,
              top: 0,
              bottom: 0,
              width: _itemWidth,
              child: Container(
                decoration: BoxDecoration(
                  gradient: Palette.lampGlow,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: -4)],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  SizedBox(
                    width: _itemWidth,
                    child: Semantics(
                      selected: i == index,
                      child: Pressable(
                        onTap: () => onSelect(i),
                        lift: false,
                        semanticLabel: _items[i].$1,
                        child: SizedBox(
                          height: 60,
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(i == index ? _items[i].$3 : _items[i].$2, size: 22, color: i == index ? Palette.deep : Palette.bone),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: Motion.quick,
                                  style: text(
                                    size: 12.5,
                                    weight: FontWeight.w600,
                                    height: 1.1,
                                    color: i == index ? Palette.deep : Palette.haze,
                                  ),
                                  child: Text(_items[i].$1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
