import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tts_provider.dart';

class TtsDemoScreen extends StatefulWidget {
  const TtsDemoScreen({super.key});

  @override
  State<TtsDemoScreen> createState() => _TtsDemoScreenState();
}

class _TtsDemoScreenState extends State<TtsDemoScreen> {
  final _controller = TextEditingController(
    text: 'Halo! Ini demo TTS jejak cerita rakyat. Selamat mendengarkan.',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('TTS Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Teks untuk dibacakan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _SliderTile(
              label: 'Kecepatan (rate) ${tts.rate.toStringAsFixed(2)}',
              value: tts.rate,
              min: 0.2,
              max: 1.0,
              onChanged: (v) => context.read<TtsProvider>().setRate(v),
            ),
            _SliderTile(
              label: 'Pitch ${tts.pitch.toStringAsFixed(2)}',
              value: tts.pitch,
              min: 0.6,
              max: 1.4,
              onChanged: (v) => context.read<TtsProvider>().setPitch(v),
            ),
            _SliderTile(
              label: 'Volume ${tts.volume.toStringAsFixed(2)}',
              value: tts.volume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => context.read<TtsProvider>().setVolume(v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<TtsProvider>().speak(_controller.text),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
                ElevatedButton.icon(
                  onPressed: tts.speaking
                      ? () => context.read<TtsProvider>().pause()
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                ElevatedButton.icon(
                  onPressed: tts.speaking || tts.paused
                      ? () => context.read<TtsProvider>().stop()
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tts.speaking ? (tts.paused ? 'Paused' : 'Speaking...') : 'Idle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            const Text(
              'Tip: Bahasa diset ke id-ID. Ubah di provider jika perlu.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value, onChanged: onChanged, min: min, max: max),
      ],
    );
  }
}
