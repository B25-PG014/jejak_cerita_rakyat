// lib/providers/tts_provider.dart
import 'dart:async';
import 'dart:ui' show TextRange;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool get ready => _ready;

  // ===== state publik =====
  final ValueNotifier<bool> speakingVN = ValueNotifier<bool>(false);
  bool get speaking => speakingVN.value;

  // highlight aktif (dipakai ReaderScreen)
  final ValueNotifier<TextRange> active = ValueNotifier<TextRange>(
    const TextRange(start: 0, end: 0),
  );
  void Function(String text, int start, int end, String? word)? onProgress;

  // Event selesai bicara (untuk auto-advance)
  final StreamController<void> _onCompleteCtrl =
      StreamController<void>.broadcast();
  Stream<void> get onComplete => _onCompleteCtrl.stream;

  // scope optional
  String? _currentContentId;

  // volume (dipakai UI)
  double _volume = 1.0;
  double get volume => _volume;
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_ready) await _tts.setVolume(_volume);
    notifyListeners();
  }

  Future<void> init() async {
    if (_ready) return;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(_volume);

    // ---- Hook handlers langsung dari engine ----
    _tts.setStartHandler(() {
      speakingVN.value = true;
    });
    _tts.setCancelHandler(() {
      speakingVN.value = false;
    });
    _tts.setCompletionHandler(() {
      speakingVN.value = false;
      // beri sinyal ke auto-read
      try {
        _onCompleteCtrl.add(null);
      } catch (_) {}
    });
    _tts.setErrorHandler((msg) {
      speakingVN.value = false;
    });

    // Progress (optional, jika plugin kamu support)
    _tts.setProgressHandler((String text, int start, int end, String word) {
      onProgress?.call(text, start, end, word);
    });

    // Android queue mode -> flush (best effort)
    try {
      final dyn = _tts as dynamic;
      await dyn.setQueueMode?.call(1);
    } catch (_) {}

    // Warmup
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

  // ========== API lama/kompat ==========
  Future<void> speak(String text) async {
    await ensureReady();
    await _tts.stop();
    // safeguard; nanti akan di-set false oleh completion/cancel/error handler
    speakingVN.value = true;
    await _tts.speak(text);
  }

  Future<void> speakText(String text) => speak(text);

  Future<void> speakScoped({
    required String contentId,
    required String text,
  }) async {
    await ensureReady();
    if (_currentContentId != contentId) {
      await _tts.stop();
      _currentContentId = contentId;
    }
    speakingVN.value = true;
    await _tts.speak(text);
  }

  Future<void> clearScope() async {
    _currentContentId = null;
    await _tts.stop();
    speakingVN.value = false;
  }

  Future<void> stop() async {
    await _tts.stop();
    speakingVN.value = false;
  }

  @override
  void dispose() {
    speakingVN.dispose();
    active.dispose();
    _onCompleteCtrl.close();
    super.dispose();
  }
}
