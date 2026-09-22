import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/shell.dart';
import 'package:voces/theme.dart';

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
    _api.restore().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voces del Lugar',
      debugShowCheckedModeBanner: false,
      theme: vocesTheme(),
      home: _ready ? AppShell(api: _api) : const Scaffold(body: Center(child: Text('Voces del Lugar'))),
    );
  }
}
