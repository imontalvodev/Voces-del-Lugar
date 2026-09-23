import 'dart:async';

import 'package:flutter/material.dart';

class RecordingControl extends StatefulWidget {
  const RecordingControl({super.key, required this.url, required this.play, required this.stop, this.completed});

  final String url;
  final Future<void> Function(String url) play;
  final Future<void> Function() stop;
  final Stream<void>? completed;

  @override
  State<RecordingControl> createState() => _RecordingControlState();
}

class _RecordingControlState extends State<RecordingControl> {
  var _playing = false;
  var _busy = false;
  StreamSubscription<void>? _completed;

  @override
  void initState() {
    super.initState();
    _listenCompleted();
  }

  @override
  void didUpdateWidget(covariant RecordingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed != widget.completed) {
      _completed?.cancel();
      _listenCompleted();
    }
  }

  void _listenCompleted() {
    final stream = widget.completed;
    if (stream == null) return;
    _completed = stream.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _completed?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await widget.stop();
        if (mounted) setState(() => _playing = false);
        return;
      }
      await widget.play(widget.url);
      if (mounted) setState(() => _playing = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: _busy ? null : _toggle,
        child: Text(_playing ? 'Parar' : 'Escuchar'),
      ),
    );
  }
}
