// Compat layer supaya UI lama tetap compile saat pakai TtsProvider minimal.
import 'dart:ui' show TextRange;
import 'package:flutter/foundation.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';

// Samakan signature callback lama
typedef TtsProgressCallback =
    void Function(String text, int start, int end, String? word);

// Notifier global sederhana (tidak akan ter-update karena provider minimal)
final ValueNotifier<TextRange> _compatActive = ValueNotifier(TextRange.empty);

// Simpan callback terakhir (tidak dipakai karena provider minimal tak set progress)
TtsProgressCallback? _lastOnProgress;

/// Extension yang menambahkan properti/metode lama sebagai no-op/alias
extension TtsCompat on TtsProvider {
  // ====== Getter lama (dummy) ======
  bool get speaking => false;
  bool get paused => false;

  double get rate => 0.5;
  double get pitch => 1.0;
  double get volume => 1.0;

  // ====== Notifier highlight lama (dummy) ======
  ValueNotifier<TextRange> get active => _compatActive;

  // ====== Setter parameter (no-op) ======
  Future<void> setRate(double v) async {}
  Future<void> setPitch(double v) async {}
  Future<void> setVolume(double v) async {}

  // ====== Pause/Resume lama (fallback ke stop/no-op) ======
  Future<void> pause() async {
    await stop();
  }

  Future<void> resume() async {}

  // ====== onProgress lama (disimpan saja agar tidak error) ======
  set onProgress(TtsProgressCallback? cb) {
    _lastOnProgress = cb;
  }

  // ====== Alias speak -> speakText ======
  Future<void> speak(String text, {bool isSsml = false}) => speakText(text);
}
