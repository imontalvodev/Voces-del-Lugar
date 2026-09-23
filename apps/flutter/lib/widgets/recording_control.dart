import 'package:flutter/material.dart';

class RecordingControl extends StatefulWidget {
  const RecordingControl({super.key, required this.url, required this.play, required this.stop});

  final String url;
  final Future<void> Function(String url) play;
  final Future<void> Function() stop;

  @override
  State<RecordingControl> createState() => _RecordingControlState();
}

class _RecordingControlState extends State<RecordingControl> {
  var _playing = false;

  Future<void> _toggle() async {
    if (_playing) {
      await widget.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await widget.play(widget.url);
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(onPressed: _toggle, child: Text(_playing ? 'Parar' : 'Escuchar')),
    );
  }
}
