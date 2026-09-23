import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/shell.dart';
import 'package:voces/ui/sky.dart';
import 'package:voces/ui/tokens.dart';

void main() {
  runApp(const VocesApp());
}

class VocesApp extends StatefulWidget {
  const VocesApp({super.key});

  @override
  State<VocesApp> createState() => _VocesAppState();
}

class _VocesAppState extends State<VocesApp> {
  final _api = VocesApi();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _api.restore().whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voces del Lugar',
      debugShowCheckedModeBanner: false,
      theme: vocesTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _ready
            ? AppShell(api: _api)
            : Scaffold(
                backgroundColor: Palette.night,
                body: Sky(
                  child: Center(child: Text('Voces del Lugar', style: display(40))),
                ),
              ),
      ),
    );
  }
}
