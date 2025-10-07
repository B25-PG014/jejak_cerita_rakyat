// lib/providers/tts_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool get ready => _ready;

  // Scope ID untuk memastikan yang dibacakan sesuai konteks (reader/sinopsis, dll.)
  String? _currentContentId;

  Future<void> init() async {
    if (_ready) return;

    // Urutan init penting
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(
      'id-ID',
    ); // fallback akan ditangani engine jika tak tersedia
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // Android: mode antrean flush (panggil via dynamic agar aman di berbagai versi plugin)
    try {
      final dyn = _tts as dynamic;
      await dyn.setQueueMode?.call(1); // 1 = flush (FlutterTtsQueueMode.flush)
    } catch (_) {
      // abaikan jika tidak tersedia
    }

    // Warm-up untuk 'membangunkan' engine di sebagian device
    try {
      await _tts.speak(' ');
      await _tts.stop();
    } catch (_) {}

    _ready = true;
    notifyListeners();
  }

  Future<void> ensureReady() async {
    if (!_ready) await init();
  }

  /// Bicara teks biasa (tanpa scope). Dipakai oleh kode lama / compat adapter.
  Future<void> speakText(String text) async {
    await ensureReady();
    await _tts.stop(); // pastikan bersih
    await _tts.speak(text);
  }

  /// Bicara dengan "scope" tertentu — jika scope berubah, state/queue lama di-flush.
  /// Gunakan contentId unik, misal:
  /// 'reader-<storyId>-page-<index>' atau 'synopsis-<storyId>'.
  Future<void> speakScoped({
    required String contentId,
    required String text,
  }) async {
    await ensureReady();
    if (_currentContentId != contentId) {
      // konten berbeda → hentikan sisa state sebelumnya
      await _tts.stop();
      _currentContentId = contentId;
    }
    await _tts.speak(text);
  }

  /// Hentikan dan kosongkan scope aktif (panggil saat keluar layar).
  Future<void> clearScope() async {
    _currentContentId = null;
    await _tts.stop();
  }

  Future<void> stop() async => _tts.stop();
}
