import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/account_page.dart';
import 'package:voces/pages/compose_page.dart';
import 'package:voces/pages/home_page.dart';
import 'package:voces/pages/map_page.dart';
import 'package:voces/theme.dart';

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
    _mapKey.currentState?.beginPlacing();
  }

  Future<void> _leaveStory(LatLng point) async {
    if (widget.api.account == null) {
      _pendingPoint = point;
      setState(() => _index = 2);
      return;
    }
    _pendingPoint = null;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ComposePage(api: widget.api, point: point)),
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
      HomePage(key: _homeKey, api: widget.api, onLeaveStory: _choosePointOnMap),
      MapPage(key: _mapKey, api: widget.api, onLeaveStory: _leaveStory),
      AccountPage(
        key: _accountKey,
        api: widget.api,
        onChanged: () {
          setState(() {});
          final pending = _pendingPoint;
          if (pending != null && widget.api.account != null) _leaveStory(pending);
        },
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: _index, children: pages);
    final rail = _SideRail(
      index: _index,
      vertical: wide,
      onSelect: (index) => setState(() => _index = index),
    );
    return Scaffold(
      backgroundColor: VocesColors.desk,
      body: wide ? Row(children: [rail, Expanded(child: body)]) : Column(children: [rail, Expanded(child: body)]),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.index, required this.vertical, required this.onSelect});

  final int index;
  final bool vertical;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final links = [
      (0, 'Inicio'),
      (1, 'Mapa'),
      (2, 'Cuenta'),
    ];
    final nav = [
      for (final link in links)
        _NavLink(label: link.$2, selected: index == link.$1, onTap: () => onSelect(link.$1)),
    ];
    if (!vertical) {
      return Material(
        color: VocesColors.ink,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('Voces del Lugar', style: vocesDisplay(18, color: VocesColors.inkOnDesk)),
                const Spacer(),
                ...nav,
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: VocesColors.ink,
      child: SizedBox(
        width: 96,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    'Voces del Lugar',
                    style: vocesDisplay(16, color: VocesColors.inkOnDesk).copyWith(letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 36),
                ...nav,
                const Spacer(),
                Text('40.42°N\n3.70°O', textAlign: TextAlign.center, style: vocesMono(size: 11, color: VocesColors.mutedOnDesk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Text(
            label,
            style: vocesSans(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? VocesColors.inkOnDesk : VocesColors.mutedOnDesk,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
