// lib/providers/tts_compat_adapter.dart

import 'dart:async';
import 'dart:ui' show TextRange;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Pull in your minimal/real TtsProvider type so the extension can attach to it.
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';

/// ===============================
/// 1) Back-compat extension for UI
/// ===============================

// Samakan signature callback lama
typedef TtsProgressCallback =
    void Function(String text, int start, int end, String? word);

// Notifier global sederhana (dipakai oleh UI lama untuk highlight)
final ValueNotifier<TextRange> _compatActive = ValueNotifier<TextRange>(
  TextRange.empty,
);

// Simpan callback terakhir agar tidak error saat UI set onProgress
// ignore: unused_field
TtsProgressCallback? _lastOnProgress;

/// Extension yang menyediakan API lama di atas TtsProvider.
/// Ini supaya referensi seperti `speaking`, `rate`, `setVolume`, `onProgress`, `speak`
/// di Detail/Reader/TTS Demo tidak error walau implementasinya minimal/no-op.
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
    // panggil stop() milik TtsProvider minimal jika ada
    try {
      await stop();
    } catch (_) {}
  }

  Future<void> resume() async {}

  // ====== onProgress lama (disimpan agar tidak error) ======
  set onProgress(TtsProgressCallback? cb) {
    _lastOnProgress = cb;
  }

  // ====== Alias speak -> speakText (UI lama memanggil speak) ======
  Future<void> speak(String text, {bool isSsml = false}) => speakText(text);
}

/// ===========================================
/// 2) Adapter sederhana untuk kontrol TTS nyata
/// ===========================================
/// Gunakan ini di tempat yang butuh kontrol TTS real-time (auto-read, stop saat pindah halaman, dsb).
class TtsCompatAdapter extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  final StreamController<void> _doneCtrl = StreamController<void>.broadcast();
  Stream<void> get onComplete => _doneCtrl.stream;

  TtsCompatAdapter() {
    // Trigger ketika satu kali speak() selesai
    _tts.setCompletionHandler(() {
      _doneCtrl.add(null);
    });

    // Anggap selesai juga saat cancel/pause/error
    _tts.setCancelHandler(() => _doneCtrl.add(null));
    _tts.setPauseHandler(() => _doneCtrl.add(null));
    _tts.setErrorHandler((msg) => _doneCtrl.add(null));

    // (opsional) set default
    // _tts.setLanguage('id-ID');
    // _tts.setSpeechRate(0.5);
    // _tts.setPitch(1.0);
    // _tts.setVolume(1.0);
  }

  /// Bicara teks. Selalu menghentikan bacaan sebelumnya agar tidak overlap.
  Future<void> speak(String text) async {
    await stop(); // pastikan tidak tumpang tindih
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  /// Hentikan TTS (aman dipanggil berkali-kali).
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _doneCtrl.close();
    super.dispose();
  }
}
