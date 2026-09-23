import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voces/api.dart';

class PlaceJump extends StatefulWidget {
  const PlaceJump({super.key, required this.search, required this.onPick});

  final Future<List<PlaceHit>> Function(String query) search;
  final ValueChanged<PlaceHit> onPick;

  @override
  State<PlaceJump> createState() => _PlaceJumpState();
}

class _PlaceJumpState extends State<PlaceJump> {
  final _text = TextEditingController();
  Timer? _wait;
  List<PlaceHit> _hits = [];
  String? _error;

  @override
  void dispose() {
    _wait?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 400), () => _run(value));
  }

  Future<void> _run(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _hits = []);
      return;
    }
    try {
      final hits = await widget.search(query);
      if (!mounted || _text.text.trim() != query) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _hits = hits;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _pick(PlaceHit hit) {
    widget.onPick(hit);
    _text.clear();
    setState(() => _hits = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Ir a una ciudad o un lugar', isDense: true),
          onChanged: _schedule,
        ),
        if (_error != null) Text(_error!),
        for (final hit in _hits)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => _pick(hit), child: Text(hit.label, textAlign: TextAlign.start)),
          ),
      ],
    );
  }
}
