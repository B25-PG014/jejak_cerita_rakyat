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

  // ====== PATCH realtime volume ======
  // simpan teks sumber & posisi terakhir yang telah diucap (index original)
  String _sourceRaw = '';
  int _lastOriginalIdx = 0;
  Timer? _volDebounce;

  Future<void> setVolume(double v) async {
    // method lama tetap ada untuk kompatibilitas (tidak realtime)
    _volume = v.clamp(0.0, 1.0);
    if (_ready) await _tts.setVolume(_volume);
    notifyListeners();
  }

  // Gunakan ini dari UI agar terasa real-time saat sedang bicara
  Future<void> setVolumeRealtime(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_ready) await _tts.setVolume(_volume);
    notifyListeners();

    if (speakingVN.value) {
      _volDebounce?.cancel();
      _volDebounce = Timer(const Duration(milliseconds: 160), () async {
        await _softRestartAtBoundary();
      });
    }
  }

  // ====== STATE untuk sinkronisasi highlight ======
  // Teks yang dipakai engine (setelah normalisasi)
  String _engineText = '';
  // Pemetaan indeks: posisi i pada _engineText -> posisi di teks original
  // Panjangnya == _engineText.length; setiap elemen berisi index original.
  List<int> _engineToOriginal = const [];

  Future<void> init() async {
    if (_ready) return;

    await _tts.awaitSpeakCompletion(true);

    // (opsional) fokus audio, jika tersedia pada plugin
    try {
      final dyn = _tts as dynamic;
      await dyn.setAudioFocus?.call(true);
    } catch (_) {}

    await _pickIndonesianVoice();
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(0.88);
    await _tts.setVolume(_volume);

    _tts.setStartHandler(() {
      speakingVN.value = true;
    });
    _tts.setCancelHandler(() {
      speakingVN.value = false;
    });
    _tts.setCompletionHandler(() {
      speakingVN.value = false;
      try {
        _onCompleteCtrl.add(null);
      } catch (_) {}
    });
    _tts.setErrorHandler((msg) {
      speakingVN.value = false;
    });

    // Pasang progress handler → tetap forward, tapi kamu akan memetakan di UI
    _tts.setProgressHandler((String text, int start, int end, String word) {
      onProgress?.call(text, start, end, word);
      // catat posisi original terakhir yg sudah lewat (pakai 'end')
      try {
        _lastOriginalIdx = mapEngineToOriginal(end);
      } catch (_) {}
    });

    try {
      final dyn = _tts as dynamic;
      await dyn.setQueueMode?.call(1);
    } catch (_) {}

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

  // ==============================
  // ==== API lama / kompatibel ====
  // ==============================
  Future<void> speak(String text) async {
    await ensureReady();
    await _tts.stop();
    // Siapkan peta sinkronisasi berdasarkan "text" yang akan dibaca
    setSourceText(text);

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
    setSourceText(text);
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

  // =========================
  // ====== PATCH BARU =======
  // =========================

  /// Panggil sebelum mulai `speak()` untuk menyiapkan peta indeks
  /// agar highlight sinkron dengan offset dari engine.
  void setSourceText(String raw) {
    _sourceRaw = raw; // simpan sumber untuk soft-restart
    final res = _buildEngineIndex(raw);
    _engineText = res.$1;
    _engineToOriginal = res.$2;
  }

  /// Konversi indeks dari engine → indeks di teks original.
  int mapEngineToOriginal(int idx) {
    if (_engineToOriginal.isEmpty) return idx.clamp(0, idx);
    if (idx <= 0) return 0;
    if (idx >= _engineToOriginal.length) {
      return _engineToOriginal.isNotEmpty ? _engineToOriginal.last : 0;
    }
    return _engineToOriginal[idx];
  }

  /// Normalisasi yang meniru kebiasaan engine TTS:
  /// - collapse whitespace (space/newline/tab) → satu spasi
  /// - buang whitespace AWAL (LEADING) sepenuhnya → *patch penting untuk P1 geser*
  /// - ganti ellipsis “…” → "..."
  /// - buang zero-width chars & sebagian emoji umum (opsional)
  /// Kembalikan (engineText, indexMap)
  (String, List<int>) _buildEngineIndex(String original) {
    final out = StringBuffer();
    final map = <int>[];

    bool lastWasSpace = false;
    bool emittedAny =
        false; // <<=== PATCH: sudah ada karakter (bukan leading space)?

    // Regex sederhana untuk skip karakter yang sering diabaikan engine
    final zeroWidth = RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]');
    // Emoji umum (rentang dasar) — bukan sempurna, tapi cukup membantu
    final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);

    for (int i = 0; i < original.length; i++) {
      var ch = original[i];

      // Ubah ellipsis
      if (ch == '…') {
        final rep = '...';
        for (int k = 0; k < rep.length; k++) {
          out.write(rep[k]);
          map.add(i);
        }
        lastWasSpace = false;
        emittedAny = true;
        continue;
      }

      // Normalisasi whitespace
      if (ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ') {
        // PATCH: abaikan semua leading whitespace sebelum ada karakter apa pun
        if (!emittedAny) {
          // skip total
          continue;
        }
        if (!lastWasSpace) {
          out.write(' ');
          map.add(i);
          lastWasSpace = true;
          emittedAny = true; // kita tetap anggap sudah mulai output
        }
        continue;
      } else {
        lastWasSpace = false;
      }

      // Buang zero-width / emoji yang sering di-skip
      if (zeroWidth.hasMatch(ch) || emoji.hasMatch(ch)) {
        continue;
      }

      // Karakter biasa
      out.write(ch);
      map.add(i);
      emittedAny = true;
    }

    // Trim trailing spasi yang mungkin tersisa
    var engineText = out.toString();
    if (engineText.isNotEmpty && engineText[engineText.length - 1] == ' ') {
      engineText = engineText.substring(0, engineText.length - 1);
      if (map.isNotEmpty) {
        map.removeLast();
      }
    }
    return (engineText, map);
  }

  /// Pilih voice Bahasa Indonesia jika tersedia; fallback ke setLanguage('id-ID').
  Future<void> _pickIndonesianVoice() async {
    try {
      final raw = await _tts.getVoices;
      final voices = (raw is List) ? List<Map>.from(raw) : const <Map>[];
      Map? best = voices.firstWhere(
        (v) {
          final loc = (v['locale'] ?? '').toString().toLowerCase();
          final name = (v['name'] ?? '').toString().toLowerCase();
          return loc.startsWith('id') &&
              (name.contains('female') || name.contains('natural'));
        },
        orElse: () => voices.firstWhere(
          (v) =>
              ((v['locale'] ?? '').toString().toLowerCase().startsWith('id')),
          orElse: () => {},
        ),
      );
      if (best.isNotEmpty) {
        await _tts.setVoice({'name': best['name'], 'locale': best['locale']});
        return;
      }
    } catch (_) {}
    await _tts.setLanguage('id-ID');
  }

  // ====== Soft-restart di batas kalimat agar volume terasa real-time ======
  Future<void> _softRestartAtBoundary() async {
    if (!speakingVN.value || _sourceRaw.isEmpty) return;

    final start = _nextSentenceStart(_sourceRaw, _lastOriginalIdx);
    final safeStart = (start != null && start < _sourceRaw.length)
        ? start
        : _lastOriginalIdx.clamp(0, _sourceRaw.length);

    final remaining = _sourceRaw.substring(safeStart).trimLeft();
    if (remaining.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    // rebuild peta sinkronisasi terhadap sisa teks
    setSourceText(remaining);
    speakingVN.value = true;
    await _tts.setVolume(_volume); // pastikan volume baru terpakai
    await _tts.speak(remaining);
  }

  int? _nextSentenceStart(String s, int idx) {
    if (idx <= 0) idx = 0;
    if (idx >= s.length) return null;

    final punct = RegExp(r'[\.!\?…]');
    for (int i = idx; i < s.length; i++) {
      if (punct.hasMatch(s[i])) {
        int j = i + 1;
        while (j < s.length && RegExp(r'\s').hasMatch(s[j])) {
          j++;
        }
        return (j < s.length) ? j : null;
      }
    }
    // fallback: ke spasi terdekat agar tidak memotong di tengah kata
    for (int i = idx; i < s.length; i++) {
      if (RegExp(r'\s').hasMatch(s[i])) return i + 1;
    }
    return null;
  }

  @override
  void dispose() {
    speakingVN.dispose();
    active.dispose();
    _onCompleteCtrl.close();
    super.dispose();
  }
}
