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
    return Scaffold(
      backgroundColor: VocesColors.field,
      body: Column(
        children: [
          _Masthead(
            index: _index,
            accountName: widget.api.account?.displayName,
            onSelect: (index) => setState(() => _index = index),
          ),
          const Divider(height: 1, color: VocesColors.line),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.index, required this.accountName, required this.onSelect});

  final int index;
  final String? accountName;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final links = [
      (0, 'Inicio'),
      (1, 'Mapa'),
      (2, accountName ?? 'Cuenta'),
    ];
    final nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final link in links)
          _NavLink(label: link.$2, selected: index == link.$1, onTap: () => onSelect(link.$1)),
      ],
    );
    return Material(
      color: VocesColors.field,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 20, 14),
        child: wide
            ? Row(
                children: [
                  Text('Voces del Lugar', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  nav,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voces del Lugar', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  nav,
                ],
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
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? VocesColors.seal : VocesColors.ink,
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: Semantics(
          selected: selected,
          child: Text(label, style: TextStyle(decoration: selected ? TextDecoration.underline : null, decorationThickness: 2, decorationColor: VocesColors.seal)),
        ),
      ),
    );
  }
}
