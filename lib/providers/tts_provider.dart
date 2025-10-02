// lib/providers/tts_provider.dart
import 'dart:io' show Platform;
import 'dart:ui' show TextRange;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

typedef TtsProgressCallback =
    void Function(String text, int start, int end, String? word);

class TtsProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  // ======== State yang diharapkan UI lama ========
  bool _ready = false;
  bool get ready => _ready;

  bool _speaking = false;
  bool get speaking => _speaking;

  bool _paused = false;
  bool get paused => _paused;

  int _highlightStart = 0;
  int get highlightStart => _highlightStart;

  int _highlightEnd = 0;
  int get highlightEnd => _highlightEnd;

  // Setter callback progress yang dipakai Reader untuk auto-scroll legacy
  TtsProgressCallback? onProgress;

  // Parameter umum (bisa diubah dari UI)
  double _rate = 0.45;
  double _pitch = 1.0;
  double _volume = 1.0;

  // === GETTERS untuk UI (TtsDemoScreen pakai ini) ===
  double get rate => _rate;
  double get pitch => _pitch;
  double get volume => _volume;

  // Highlight range agar hanya RichText yang rebuild
  final ValueNotifier<TextRange> active = ValueNotifier(TextRange.empty);

  // ======== Inisialisasi aman ========
  Future<void> init() async {
    if (_ready) return;

    // Pastikan speak() menunggu selesai (supaya loop segmen berurutan)
    await _tts.awaitSpeakCompletion(true);

    // Terapkan parameter default
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);

    // Set bahasa (fallback en-US jika id-ID tidak tersedia di device/emulator)
    try {
      final hasId = (await _tts.isLanguageAvailable('id-ID')) == true;
      await _tts.setLanguage(hasId ? 'id-ID' : 'en-US');
    } catch (_) {
      // Abaikan jika engine tidak mendukung query language; biarkan default engine
    }

    // Optional API (tidak semua versi plugin punya) → panggil via dynamic agar lolos kompilasi
    final dyn = _tts as dynamic;
    try {
      await dyn.setQueueMode?.call(1);
    } catch (_) {}
    if (Platform.isIOS) {
      try {
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      } catch (_) {}
    }

    // Progress handler untuk highlight + lempar ke onProgress (jika dipasang dari UI)
    _setProgressHandlers();

    _ready = true;
    notifyListeners();
  }

  void _setProgressHandlers() {
    // Android biasanya: (text, start, end, word)
    try {
      _tts.setProgressHandler((String text, int start, int end, String word) {
        _highlightStart = start;
        _highlightEnd = end;

        // → kabarkan ke UI yang mendengarkan tts.active (ringan, tanpa rebuild panel)
        active.value = TextRange(start: start, end: end);

        // Tetap lempar ke callback lama jika ada (dipakai untuk auto-scroll)
        onProgress?.call(text, start, end, word);

        // Penting: JANGAN notifyListeners() di sini, supaya tidak jank tiap tick
      });
    } catch (_) {}
  }

  // ======== API lama yang diharapkan UI ========

  Future<void> setRate(double v) async {
    _rate = v.clamp(0.3, 0.9);
    await _tts.setSpeechRate(_rate);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    _pitch = v.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    notifyListeners();
  }

  /// Metode lama yang dipanggil UI: langsung ngomong.
  /// Ini sekarang otomatis **chunking** agar tidak terputus di engine.
  Future<void> speak(String text, {bool isSsml = false}) async {
    await init();
    _paused = false;
    _speaking = true;
    notifyListeners();

    if (isSsml) {
      // Banyak voice menerima SSML langsung; jika gagal, fallback ke plain chunk.
      try {
        // Flush antrian sebelumnya sebelum mulai
        try {
          await _tts.stop();
        } catch (_) {}
        await _tts.speak(text.trim());
        _speaking = false;
        notifyListeners();
        return;
      } catch (_) {
        // jatuh ke chunking plain
      }
    }

    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) {
      _speaking = false;
      notifyListeners();
      return;
    }

    final chunks = _splitToChunks(clean, maxLen: 240);

    // Flush antrian lama dulu supaya tidak bentrok
    try {
      await _tts.stop();
    } catch (_) {}

    for (final seg in chunks) {
      if (_paused == true) break; // berhenti jika user pause
      await _tts.speak(seg);
      // jeda ringan agar buffer engine stabil
      await Future.delayed(const Duration(milliseconds: 80));
    }

    _speaking = false;
    notifyListeners();
  }

  /// Versi aman untuk teks panjang (alias lama bisa panggil ini juga)
  Future<void> speakText(String text) => speak(text);

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
    _paused = false;
    notifyListeners();
  }

  Future<void> pause() async {
    // pause() tidak selalu tersedia di semua platform/voice – panggil via dynamic
    final dyn = _tts as dynamic;
    try {
      await dyn.pause?.call();
      _paused = true;
      _speaking = false;
      notifyListeners();
    } catch (_) {
      // fallback: stop jika pause tak didukung
      await stop();
    }
  }

  Future<void> resume() async {
    final dyn = _tts as dynamic;
    try {
      await dyn.resume?.call();
      _paused = false;
      _speaking = true;
      notifyListeners();
    } catch (_) {
      // kalau resume tidak ada, UI bisa panggil speak() ulang dari posisi terakhir (pakai highlightStart/End)
    }
  }

  // ======== Utilities ========
  List<String> _splitToChunks(String input, {int maxLen = 240}) {
    final sentences = input.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    var buf = StringBuffer();

    for (final s0 in sentences) {
      final s = s0.trim();
      if (s.isEmpty) continue;

      if ((buf.length + s.length + 1) <= maxLen) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(s);
      } else {
        if (buf.isNotEmpty) {
          chunks.add(buf.toString());
          buf = StringBuffer();
        }
        if (s.length > maxLen) {
          chunks.addAll(_hardWrap(s, maxLen));
        } else {
          buf.write(s);
        }
      }
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  List<String> _hardWrap(String s, int maxLen) {
    final words = s.split(' ');
    final out = <String>[];
    var buf = StringBuffer();

    for (final w in words) {
      if ((buf.length + w.length + 1) <= maxLen) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(w);
      } else {
        out.add(buf.toString());
        buf = StringBuffer(w);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  @override
  void dispose() {
    active.dispose();
    _tts.stop();
    super.dispose();
  }
}
