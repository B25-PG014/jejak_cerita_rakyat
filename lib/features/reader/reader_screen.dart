// lib/features/reader/reader_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TextRange;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/providers/reader_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';
// Compat adapter agar API lama (speak/speaking/active/volume...) tetap compile
import 'package:jejak_cerita_rakyat/providers/tts_compat_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jejak_cerita_rakyat/core/local/reading_progress_store.dart';

// === Tambahan import minimal untuk patch ===
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/features/library/library_screen.dart';

// ======= DEBUG HELPERS =======
// set false untuk mematikan semua log
const bool kTtsDebug = false;

@pragma('vm:prefer-inline')
void dlog(String msg) {
  if (kTtsDebug) debugPrint('[TTSDBG] $msg');
}

@pragma('vm:prefer-inline')
String shortStr(String s, [int n = 48]) {
  if (s.length <= n) return s.replaceAll('\n', '⏎');
  return '${s.substring(0, n).replaceAll('\n', '⏎')}…';
}

// ======= MODE PILIHAN =======
// Gunakan mode “smooth follow” agar highlight mulus mengikuti durasi estimasi,
// cocok untuk voice natural (progress event sering tidak stabil).
const bool kUseSmoothFollow = true; // <- aktifkan natural mode untuk semua page

// ======= PACE GUARD (opsional, off) =======
// NOTE: tidak dipakai saat smooth follow
const bool kPaceGuard = false;
const double kBaseCps = 13.8;
const double kLeadAllowance = 0.12;
const double kCpsMin = 8.0;
const double kCpsMax = 22.0;
const double kEmaAlpha = 0.30;
const int kAntiStallMs = 900;
const double kAntiStallStep = 0.05;
const double kAntiStallMax = 0.18;

// ======= LAG QUEUE (dipakai kalau kUseSmoothFollow=false) =======
const int kLagMs = 280;
const int kFlushEveryMs = 30;

// ======= SMOOTH FOLLOW PARAMS =======
// Update lebih “tenang” untuk mengurangi flicker
const int kSmoothTickMs = 60; // 40ms -> 90ms
const double kSmoothLead = 0.02; // tetap sedikit “di depan”
const int kMinAdvance = 2; // minimal loncat 2 char baru apply

/// PATCH: helper global untuk menyamakan string UI & string yang di-speak
String cleanZW(String s) {
  const removeChars = [
    '\uFEFF', // BOM
    '\u200B', // ZWSP
    '\u200C', // ZWNJ
    '\u200D', // ZWJ
    '\u2060', // WORD JOINER
    '\u00AD', // SOFT HYPHEN
    '\u2011', // NON-BREAKING HYPHEN
    '\u034F', // COMBINING GRAPHEME JOINER
  ];
  for (final ch in removeChars) {
    s = s.replaceAll(ch, '');
  }
  s = s.replaceAll('\t', ' ');
  s = s.replaceAll('\u00A0', ' ');
  s = s.replaceAll('\u202F', ' ');
  s = s.replaceAll('\r\n', '\n');
  s = s.replaceAll(RegExp(r' {2,}'), ' ');
  return s;
}

// ======= TOP-LEVEL: event highlight (untuk queue) =======
class _HiEv {
  final int ts;
  final int s;
  final int e;
  _HiEv(this.ts, this.s, this.e);
}

// === Helper global baru: matikan highlight & autoRead dengan aman ===
void _killHighlight(BuildContext context) {
  final parent = context.findAncestorStateOfType<_ReaderScreenState>();
  if (parent == null) return;
  parent._cancelHighlightTimers();
  parent._resetHighlight();
  parent._autoRead.value = false;
  // kosongkan visual highlight
  try {
    context.read<TtsProvider>().active.value = const TextRange(
      start: 0,
      end: 0,
    );
  } catch (_) {}
}

class ReaderScreen extends StatefulWidget {
  final int id;
  const ReaderScreen({super.key, required this.id});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final _textScroll = ScrollController();
  bool _panelExpanded = false;
  bool _openedOnce = false;
  final ValueNotifier<bool> _autoRead = ValueNotifier<bool>(false);
  bool _restoredOnce = false;
  int? _pendingTargetIndex;
  VoidCallback? _rpListener;

  // NEW: subscription selesai TTS → untuk auto-advance
  StreamSubscription<void>? _ttsDoneSub;

  // --- State untuk scroll ---
  Timer? _scrollDebounce;
  double _pendingScrollOffset = 0.0;

  // --- State highlight ---
  int _currHiStart = 0;
  int _currHiEnd = 0;

  // Timer throttle apply highlight
  Timer? _hiDelayTimer;

  // === Throttle params ===
  static const int _applyEveryMs = 50;
  static const int _scrollDebounceMs = 80;
  int _lastApplyEpochMs = 0;

  // DEBUG: waktu mulai tiap speak()
  int _speakStartEpochMs = 0;

  // ====== PACE GUARD state ======
  int _estDurMs = 0;
  double _emaCps = kBaseCps;
  int _clampStreak = 0;
  int _lastClampEpochMs = 0;

  // ====== LAG QUEUE state (untuk progress engine) ======
  final List<_HiEv> _pendingHi = <_HiEv>[];
  Timer? _flushTimer;

  // ====== SMOOTH FOLLOW timer ======
  Timer? _smoothTimer;

  void _resetHighlight() {
    _currHiStart = 0;
    _currHiEnd = 0;
  }

  void _cancelHighlightTimers() {
    _hiDelayTimer?.cancel();
    _scrollDebounce?.cancel();
    _pendingHi.clear();
    _smoothTimer?.cancel();
  }

  void _forceHighlightToEnd() {
    if (!mounted) return;
    final r = context.read<ReaderProvider>();
    if (r.pages.isEmpty) return;
    final txt = cleanZW(r.pages[r.index].textPlain ?? '');
    final end = txt.length;
    _currHiStart = (_currHiEnd <= end) ? _currHiEnd : 0;
    _currHiEnd = end;
    _pendingHi.clear();
    _smoothTimer?.cancel();
    context.read<TtsProvider>().active.value = TextRange(
      start: _currHiStart,
      end: _currHiEnd,
    );
  }

  void _resetUtteranceTiming() {
    _lastApplyEpochMs = 0;
    _emaCps = kBaseCps;
    _clampStreak = 0;
    _lastClampEpochMs = 0;
    _estDurMs = 0;
    _pendingHi.clear();
    _smoothTimer?.cancel();
  }

  Future<void> _saveReadingProgress(int? storyId, int pageIndex) async {
    try {
      if (storyId == null) return;
      await ReadingProgressStore.setPage(storyId, pageIndex);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // matikan TTS sinopsis saat masuk reader
    final tts = context.read<TtsProvider>();
    Future.microtask(() async {
      try {
        await Future.any([
          tts.stop(),
          context.read<TtsCompatAdapter>().stop(),
          Future.delayed(const Duration(milliseconds: 250)),
        ]);
      } catch (_) {}
    });

    // LAG QUEUE flusher (no-op saat kUseSmoothFollow=true)
    _flushTimer = Timer.periodic(const Duration(milliseconds: kFlushEveryMs), (
      _,
    ) {
      if (!mounted || kUseSmoothFollow) return;
      if (_pendingHi.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final ev = _pendingHi.first;
      if (now - ev.ts < kLagMs) return;
      _pendingHi.removeAt(0);

      final prov = context.read<ReaderProvider>();
      if (prov.pages.isEmpty) return;
      final txt = cleanZW(prov.pages[prov.index].textPlain ?? '');
      if (txt.isEmpty) return;

      final tts = context.read<TtsProvider>();
      _applyHighlightWithRules(txt, ev.s, ev.e, tts);
    });
  }

  // Helpers untuk baseDir
  String _sanitizeBaseDir(String? baseDir) {
    var b = (baseDir ?? '').trim();
    if (b.isEmpty) return 'assets/stories/';
    if (!b.endsWith('/')) b = '$b/';
    return b;
  }

  String _stripQuotes(String s) {
    final t = s.trim();
    if (t.length >= 2) {
      final a = t.codeUnitAt(0);
      final b = t.codeUnitAt(t.length - 1);
      if ((a == 34 && b == 34) || (a == 39 && b == 39)) {
        return t.substring(1, t.length - 1);
      }
    }
    return t;
  }

  // Precache image halaman berikutnya
  void _precacheNextPage(
    BuildContext context,
    String? nextPath,
    String baseDir,
  ) {
    if (nextPath == null) return;
    final raw = _stripQuotes(nextPath);
    if (raw.isEmpty) return;

    final p = (raw.startsWith('assets/')
        ? raw
        : (raw.startsWith('http://') || raw.startsWith('https://'))
        ? raw
        : '${_sanitizeBaseDir(baseDir)}$raw');

    final ImageProvider provider =
        (p.startsWith('http://') || p.startsWith('https://'))
        ? NetworkImage(p)
        : AssetImage(p) as ImageProvider;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(provider, context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedOnce) return;
    _openedOnce = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Buka cerita
      context.read<ReaderProvider>().openStory(widget.id);
      // Restore target halaman (tanpa lompat dulu)
      try {
        final r0 = context.read<ReaderProvider>();
        final saved = (r0.storyId != null)
            ? await ReadingProgressStore.getPage(r0.storyId!)
            : null;
        _pendingTargetIndex = saved;
      } catch (_) {
        _pendingTargetIndex = null;
      }

      // Listener satu-kali: setelah pages siap baru lompat
      final r = context.read<ReaderProvider>();
      _rpListener = () {
        if (_restoredOnce) return;
        if (r.isBusy || r.pages.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_restoredOnce) return;
          if (!mounted) return;
          if (r.pages.isEmpty) return;
          if (_pendingTargetIndex != null) {
            final target = _pendingTargetIndex!.clamp(0, r.pages.length - 1);
            if (target > r.index) {
              for (int i = r.index; i < target; i++) {
                r.nextPage();
              }
            } else if (target < r.index) {
              for (int i = r.index; i > target; i--) {
                r.prevPage();
              }
            }
          }
          _restoredOnce = true;
          if (_rpListener != null) r.removeListener(_rpListener!);
        });
      };
      r.addListener(_rpListener!);

      // ===========================
      // PROGRESS CALLBACK
      // ===========================
      final tts = context.read<TtsProvider>();
      tts.onProgress = (txtEngine, s, e, word) {
        if (kUseSmoothFollow) {
          // Natural mode: abaikan event progress (biar timer yang gerakkan highlight)
          return;
        }

        final prov = context.read<ReaderProvider>();
        if (prov.pages.isEmpty) return;
        final txt = cleanZW(prov.pages[prov.index].textPlain ?? '');
        if (txt.isEmpty) return;

        final now = DateTime.now().millisecondsSinceEpoch;
        final sinceSpeak = (_speakStartEpochMs == 0)
            ? -1
            : (now - _speakStartEpochMs);
        dlog(
          'progress(raw) t=+${sinceSpeak}ms s=$s e=$e word="${word ?? ''}" engineSeg="${shortStr((s >= 0 && e > s && s < (txtEngine.length ?? 0)) ? txtEngine.substring(s, math.min(e, (txtEngine.length ?? 0))) : '')}"',
        );

        final rDbg = prov;
        final txtDbg = (rDbg.pages.isNotEmpty
            ? (rDbg.pages[rDbg.index].textPlain ?? '')
            : '');
        final start0 = s.clamp(0, txtDbg.length);
        final end0 = e.clamp(0, txtDbg.length);
        final seg = (start0 < end0)
            ? txtDbg.substring(start0, math.min(end0, start0 + 35))
            : '';
        if (kTtsDebug) {
          debugPrint(
            '[P${rDbg.index + 1}] word="$word" s=$s e=$e | seg="${seg.replaceAll('\n', '⏎')}"',
          );
        }

        int hiS = tts.mapEngineToOriginal(s).clamp(0, txt.length);
        int hiE = tts.mapEngineToOriginal(e).clamp(hiS, txt.length);

        dlog(
          'progress(mapped) page=${prov.index + 1} start=$hiS end=$hiE len=${txt.length} seg="${shortStr(txt.substring(hiS, math.min(hiE, txt.length)))}"',
        );

        if (kPaceGuard && _speakStartEpochMs > 0) {
          final elapsed = (now - _speakStartEpochMs).clamp(1, 1 << 30);
          if (hiE > 0) {
            final instCps = (hiE / (elapsed / 1000)).clamp(kCpsMin, kCpsMax);
            _emaCps = (1 - kEmaAlpha) * _emaCps + kEmaAlpha * instCps;
            _estDurMs = ((txt.length / _emaCps) * 1000).round();
          } else if (_estDurMs == 0) {
            _estDurMs = ((txt.length / _emaCps) * 1000).round();
          }

          final baseAllowedRatio =
              ((_estDurMs == 0 ? 0.0 : (elapsed / _estDurMs)) + kLeadAllowance)
                  .clamp(0.0, 1.0);
          double extraAllowance = 0.0;
          if (_clampStreak >= 2) {
            extraAllowance = (kAntiStallStep * _clampStreak).clamp(
              0.0,
              kAntiStallMax,
            );
            if (_lastClampEpochMs > 0 &&
                now - _lastClampEpochMs > kAntiStallMs) {
              extraAllowance = (extraAllowance + 0.08).clamp(
                0.0,
                kAntiStallMax,
              );
            }
          }
          final allowedRatio = (baseAllowedRatio + extraAllowance).clamp(
            0.0,
            1.0,
          );
          final allowedMax = (allowedRatio * txt.length).floor();

          if (hiE > allowedMax) {
            hiE = allowedMax;
            if (hiS > hiE) hiS = hiE;
            _clampStreak += 1;
            _lastClampEpochMs = now;
            dlog(
              'paceGuard clamp -> allowedRatio=${allowedRatio.toStringAsFixed(3)} allowedMax=$allowedMax curr=$hiE len=${txt.length} streak=$_clampStreak',
            );
          } else {
            _clampStreak = 0;
          }
        }

        // Masuk queue (diproses dengan lag agar tidak lari duluan)
        _pendingHi.add(_HiEv(now, hiS, hiE));
        dlog('queue +1 (len=${_pendingHi.length})');
      };

      // selesai TTS → force end + auto next jika auto
      _ttsDoneSub = tts.onComplete.listen((_) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final dur = (_speakStartEpochMs == 0) ? -1 : (now - _speakStartEpochMs);
        dlog(
          'onComplete after ${dur}ms | page=${context.read<ReaderProvider>().index + 1} currHL=$_currHiStart..$_currHiEnd',
        );

        _forceHighlightToEnd();
        await Future.delayed(const Duration(milliseconds: 120));

        if (!mounted) return;
        if (!_autoRead.value) return;

        final r = context.read<ReaderProvider>();
        if (r.pages.isEmpty) return;
        final hasNext = r.index + 1 < r.pages.length;

        if (!hasNext) {
          _autoRead.value = false;
          try {
            await _saveReadingProgress(r.storyId, r.index);
          } catch (_) {}
          try {
            await context.read<TtsProvider>().stop();
          } catch (_) {}
          if (!mounted) return;

          final sp = context.read<StoryProvider>();
          final storyId = r.storyId;
          final isFav = (storyId != null) ? sp.isFavorite(storyId) : false;

          _showEndOfStorySheet(
            context,
            isFavorite: isFav,
            onToggleFavorite: () {
              if (storyId == null) return;
              sp.toggleFavorite(storyId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    isFav ? 'Dihapus dari Favorit' : 'Ditambahkan ke Favorit',
                  ),
                ),
              );
            },
            onRestart: () async {
              final tts = context.read<TtsProvider>();
              await tts.stop();
              final r = context.read<ReaderProvider>();
              for (int i = r.index; i > 0; i--) {
                r.prevPage();
              }
              _cancelHighlightTimers();
              tts.active.value = const TextRange(start: 0, end: 0);
              _resetHighlight();
              final page0 = r.pages[r.index];
              final text0 = cleanZW(page0.textPlain ?? '');
              if (text0.isNotEmpty) {
                _autoRead.value = true;
                _resetUtteranceTiming();
                _speakStartEpochMs = DateTime.now().millisecondsSinceEpoch;
                _emaCps = kBaseCps;
                _estDurMs = ((text0.length / _emaCps) * 1000).round();
                dlog(
                  'speak() page=${context.read<ReaderProvider>().index + 1} len=${text0.length} | "${shortStr(text0)}"',
                );
                if (kUseSmoothFollow) _startSmoothFollow(text0);
                await tts.speak(text0);
              }
            },
            onBrowseOthers: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
            },
          );
          return;
        }

        // Default: lanjut otomatis
        r.nextPage();
        dlog('autoNext -> page=${r.index + 1}/${r.pages.length}');
        await _saveReadingProgress(r.storyId, r.index);
        _cancelHighlightTimers();
        context.read<TtsProvider>().active.value = const TextRange(
          start: 0,
          end: 0,
        );
        _resetHighlight();

        final page = r.pages[r.index];
        final text = cleanZW(page.textPlain ?? '');
        if (text.isEmpty) return;

        await Future.delayed(const Duration(milliseconds: 200));
        await context.read<TtsProvider>().stop();
        _resetUtteranceTiming();
        _speakStartEpochMs = DateTime.now().millisecondsSinceEpoch;
        _emaCps = kBaseCps;
        _estDurMs = ((text.length / _emaCps) * 1000).round();
        dlog(
          'speak() page=${context.read<ReaderProvider>().index + 1} len=${text.length} | "${shortStr(text)}"',
        );
        if (kUseSmoothFollow) _startSmoothFollow(text);
        await context.read<TtsProvider>().speak(text);
      });
    });
  }

  // ======= SMOOTH FOLLOW =======

  // Snap ke batas kata/punctuation agar blok highlight stabil
  int _snapForwardToBoundary(String txt, int idx) {
    if (idx <= 0) return 0;
    if (idx >= txt.length) return txt.length;

    // kalau sudah di spasi/akhir kata, pakai saja
    final isWs = RegExp(r'\s').hasMatch(txt[idx - 1]);
    if (isWs) return idx;

    // cari spasi/punctuation ke depan sedikit (window kecil)
    final end = math.min(txt.length, idx + 12);
    for (int i = idx; i < end; i++) {
      final ch = txt.codeUnitAt(i);
      final isSpace = ch == 32 || ch == 10 || ch == 13 || ch == 9;
      final isPunct =
          (ch >= 33 && ch <= 47) ||
          (ch >= 58 && ch <= 64) ||
          (ch >= 91 && ch <= 96) ||
          (ch >= 123 && ch <= 126);
      if (isSpace || isPunct) {
        return i; // berhenti tepat sebelum delimiter
      }
    }
    return idx;
  }

  void _startSmoothFollow(String txt) {
    _smoothTimer?.cancel();
    if (!mounted) return;

    // Estimasi durasi awal (ms) dari panjang teks & cps yang di-EMA.
    if (_estDurMs <= 0) {
      _estDurMs = ((txt.length / _emaCps) * 1000).round();
    }
    if (_estDurMs < 1200) _estDurMs = 1200; // teks pendek jangan keburu selesai

    final tts = context.read<TtsProvider>();

    _smoothTimer = Timer.periodic(const Duration(milliseconds: kSmoothTickMs), (
      t,
    ) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_speakStartEpochMs <= 0) return;

      final elapsed = (now - _speakStartEpochMs).toDouble();
      final rawRatio = (elapsed / _estDurMs);
      final ratio = (rawRatio + kSmoothLead).clamp(0.0, 1.0);

      final targetE0 = (ratio * txt.length).floor();
      // Snap ke batas kata / delimiter agar stabil
      final targetE = _snapForwardToBoundary(txt, targetE0);

      int s = _currHiEnd;
      int e = targetE;

      // Jangan apply untuk perubahan kecil (anti flicker)
      if (e - _currHiEnd < kMinAdvance && e < txt.length) {
        return;
      }

      _applyHighlightWithRules(txt, s, e, tts);

      // selesai → hentikan timer
      if (ratio >= 1.0) {
        _smoothTimer?.cancel();
      }
    });
  }

  // Terapkan aturan hysteresis + step + throttle + autoscroll
  void _applyHighlightWithRules(String txt, int hiS, int hiE, TtsProvider tts) {
    // Hysteresis: jangan mundur
    if (hiE < _currHiEnd) {
      hiS = _currHiStart;
      hiE = _currHiEnd;
    }
    // Batasi loncatan per langkah
    const maxStep = 24;
    if (hiE > _currHiEnd + maxStep) {
      hiS = _currHiEnd;
      hiE = _currHiEnd + maxStep;
    }

    final now2 = DateTime.now().millisecondsSinceEpoch;
    final elapsed2 = now2 - _lastApplyEpochMs;

    void applyHighlightAndScroll() {
      if (!mounted) return;
      if (hiE >= _currHiEnd) {
        _currHiStart = hiS;
        _currHiEnd = hiE;

        dlog(
          'applyHL start=$_currHiStart end=$_currHiEnd ratio=${txt.isEmpty ? 0 : (_currHiEnd / txt.length).toStringAsFixed(3)} scrollHas=${_textScroll.hasClients}',
        );
        tts.active.value = TextRange(start: hiS, end: hiE);
      }

      if (_textScroll.hasClients && txt.isNotEmpty) {
        final ratio = _currHiEnd / txt.length;
        final max = _textScroll.position.maxScrollExtent;
        _pendingScrollOffset = (ratio * max).clamp(0.0, max);
        _scrollDebounce?.cancel();
        _scrollDebounce = Timer(
          const Duration(milliseconds: _scrollDebounceMs),
          () {
            if (!_textScroll.hasClients) return;
            _textScroll.animateTo(
              _pendingScrollOffset,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
            );
          },
        );
      }

      _lastApplyEpochMs = DateTime.now().millisecondsSinceEpoch;
    }

    if (elapsed2 >= _applyEveryMs ||
        _currHiEnd == 0 ||
        (hiE - _currHiEnd) <= 2) {
      _hiDelayTimer?.cancel();
      applyHighlightAndScroll();
    } else {
      final remain = _applyEveryMs - elapsed2;
      _hiDelayTimer?.cancel();
      _hiDelayTimer = Timer(Duration(milliseconds: remain), () {
        applyHighlightAndScroll();
      });
    }
  }

  @override
  void dispose() {
    try {
      final r = context.read<ReaderProvider>();
      _saveReadingProgress(r.storyId, r.index);
    } catch (_) {}
    try {
      final r = context.read<ReaderProvider>();
      if (_rpListener != null) {
        r.removeListener(_rpListener!);
      }
    } catch (_) {}
    _ttsDoneSub?.cancel();
    _textScroll.dispose();
    _scrollDebounce?.cancel();
    _hiDelayTimer?.cancel();
    _smoothTimer?.cancel();
    _flushTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // MATIKAN AUTO READ saat app ke background
      _autoRead.value = false;

      try {
        await context.read<TtsProvider>().stop();
      } catch (_) {}
      try {
        await context.read<TtsCompatAdapter>().stop();
      } catch (_) {}

      // hentikan highlight sepenuhnya
      _cancelHighlightTimers();
      _resetHighlight();
      try {
        context.read<TtsProvider>().active.value = const TextRange(
          start: 0,
          end: 0,
        );
      } catch (_) {}

      try {
        final r = context.read<ReaderProvider>();
        await _saveReadingProgress(r.storyId, r.index);
      } catch (_) {}
    }
  }

  // === Helper untuk memunculkan sheet akhir cerita dari mana saja ===
  void _presentEndSheet() async {
    if (!mounted) return;
    _autoRead.value = false;
    try {
      final tts = context.read<TtsProvider>();
      await tts.stop();
    } catch (_) {}
    try {
      final r = context.read<ReaderProvider>();
      await _saveReadingProgress(r.storyId, r.index);
    } catch (_) {}

    final r = context.read<ReaderProvider>();
    final sp = context.read<StoryProvider>();
    final tts = context.read<TtsProvider>();
    final storyId = r.storyId;
    final isFav = (storyId != null) ? sp.isFavorite(storyId) : false;

    _showEndOfStorySheet(
      context,
      isFavorite: isFav,
      onToggleFavorite: () {
        if (storyId == null) return;
        sp.toggleFavorite(storyId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              isFav ? 'Dihapus dari Favorit' : 'Ditambahkan ke Favorit',
            ),
          ),
        );
      },
      onRestart: () async {
        await tts.stop();
        for (int i = r.index; i > 0; i--) {
          r.prevPage();
        }
        _cancelHighlightTimers();
        tts.active.value = const TextRange(start: 0, end: 0);
        _resetHighlight();
        final page0 = r.pages[r.index];
        final text0 = cleanZW(page0.textPlain ?? '');
        if (text0.isNotEmpty) {
          _autoRead.value = true;
          _resetUtteranceTiming();
          _speakStartEpochMs = DateTime.now().millisecondsSinceEpoch;
          _emaCps = kBaseCps;
          _estDurMs = ((text0.length / _emaCps) * 1000).round();
          dlog(
            'speak() page=${context.read<ReaderProvider>().index + 1} len=${text0.length} | "${shortStr(text0)}"',
          );
          if (kUseSmoothFollow) _startSmoothFollow(text0);
          await tts.speak(text0);
        }
      },
      onBrowseOthers: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
      },
    );
  }

  // === Helper sheet akhir cerita ===
  void _showEndOfStorySheet(
    BuildContext context, {
    required Future<void> Function() onRestart,
    required VoidCallback onToggleFavorite,
    required VoidCallback onBrowseOthers,
    bool isFavorite = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;

        // ====== gaya tombol ======
        final RoundedRectangleBorder btnShape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        );

        final ButtonStyle outlinedStyle = OutlinedButton.styleFrom(
          shape: btnShape,
          side: BorderSide(
            color: cs.primary.withValues(alpha: 0.90),
            width: 1.2,
          ),
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );

        final ButtonStyle filledStyle = FilledButton.styleFrom(
          shape: btnShape,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
        );

        final ButtonStyle textStyle = TextButton.styleFrom(
          shape: btnShape,
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Cerita selesai',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: outlinedStyle,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onToggleFavorite();
                        },
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        label: Text(
                          isFavorite ? 'Hapus Favorit' : 'Tandai Favorit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: filledStyle,
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await onRestart();
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Ulang dari awal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: textStyle,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBrowseOthers();
                    },
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Baca cerita lain'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background (konsisten dengan Home)
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                // =================== ILUSTRASI ===================
                Positioned.fill(
                  child: Consumer<ReaderProvider>(
                    builder: (context, r, _) {
                      if (r.isBusy) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (r.pages.isEmpty) {
                        return const _EmptyStateCard();
                      }
                      final page = r.pages[r.index];

                      final baseDir = _sanitizeBaseDir(r.storyDir);

                      final String? nextRaw = (r.index + 1 < r.pages.length)
                          ? r.pages[r.index + 1].imageAsset
                          : null;
                      _precacheNextPage(context, nextRaw, baseDir);

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.98, end: 1.0).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Align(
                          key: ValueKey(r.index),
                          alignment: const Alignment(0, -1.3),
                          child: FractionallySizedBox(
                            widthFactor: 0.92,
                            heightFactor: 0.75,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _SafeStoryImage(
                                path: page.imageAsset,
                                baseDir: baseDir,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // =================== TOP BAR ===================
                const _TopGlassBar(),

                // =================== PANEL TEKS ===================
                _ReadingPanel(
                  panelExpanded: _panelExpanded,
                  onToggle: () =>
                      setState(() => _panelExpanded = !_panelExpanded),
                  textScroll: _textScroll,
                  autoReadVN: _autoRead,
                  onRequestEndSheet: _presentEndSheet,
                ),

                // bayangan lembut di bawah panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: -4,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeStoryImage extends StatelessWidget {
  const _SafeStoryImage({required this.path, required this.baseDir});
  final String? path;
  final String baseDir;

  bool _looksLikeUrl(String p) =>
      p.startsWith('http://') || p.startsWith('https://');

  String _stripQuotes(String s) {
    final t = s.trim();
    if (t.length >= 2) {
      final a = t.codeUnitAt(0), b = t.codeUnitAt(t.length - 1);
      if ((a == 34 && b == 34) || (a == 39 && b == 39)) {
        return t.substring(1, t.length - 1);
      }
    }
    return t;
  }

  String _joinBase(String raw) {
    final clean = _stripQuotes(raw);
    if (clean.isEmpty) return clean;

    if (_looksLikeUrl(clean)) return clean;
    if (clean.startsWith('assets/')) return clean;

    final b = baseDir.endsWith('/') ? baseDir : '$baseDir/';
    if (clean.startsWith('/')) return '$b${clean.substring(1)}';
    return '$b$clean';
  }

  Future<String?> _resolveAsset(String rawWithBase) async {
    // Helper: cek apakah asset ada
    Future<bool> exists(String p) async {
      try {
        await rootBundle.load(p);
        return true;
      } catch (_) {
        return false;
      }
    }

    // Kumpulkan kandidat path:
    // - path asli
    // - jika tidak diawali 'assets/', coba prefix 'assets/'
    final List<String> bases = [
      rawWithBase,
      if (!rawWithBase.startsWith('assets/')) 'assets/$rawWithBase',
    ];

    // Pola ekstensi yang umum
    final extRegex = RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false);
    const tryExts = <String>['.jpg', '.jpeg', '.png', '.webp'];

    for (final b in bases) {
      // 1) Coba path apa adanya
      if (await exists(b)) return b;

      // 2) Siapkan versi tanpa ekstensi (kalau ada), supaya bisa tukar ekstensi
      final String bNoExt = b.replaceAll(extRegex, '');

      // 3) Jika b sudah punya ekstensi, coba tukar ke format lain
      if (extRegex.hasMatch(b)) {
        for (final e in tryExts) {
          final cand = bNoExt + e;
          if (await exists(cand)) return cand;
        }
      } else {
        // 4) Jika b tidak punya ekstensi, coba tambahkan beberapa kandidat
        for (final e in tryExts) {
          final cand = b + e;
          if (await exists(cand)) return cand;
        }
        // 5) Atau tambahkan ke bNoExt juga (jaga-jaga)
        for (final e in tryExts) {
          final cand = bNoExt + e;
          if (await exists(cand)) return cand;
        }
      }
    }

    // Tidak ditemukan
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final raw = (path ?? '').trim();
    if (raw.isEmpty) return _placeholder(context);

    final resolved = _joinBase(raw);

    if (_looksLikeUrl(resolved)) {
      return Image.network(
        resolved,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveAsset(resolved),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final asset = snap.data;
        if (asset == null) return _placeholder(context);
        return Image.asset(asset, fit: BoxFit.contain);
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 42,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _TopGlassBar extends StatelessWidget {
  const _TopGlassBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 6,
      right: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back,
            onTap: () async {
              final ctx = context; // cache
              try {
                await ctx.read<TtsProvider>().stop();
              } catch (_) {}
              try {
                await ctx.read<TtsCompatAdapter>().stop();
              } catch (_) {}
              _killHighlight(ctx);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pushNamed('/settings');
            },
          ),
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.settings,
                onTap: () async {
                  final ctx = context;
                  try {
                    await ctx.read<TtsProvider>().stop();
                  } catch (_) {}
                  try {
                    await ctx.read<TtsCompatAdapter>().stop();
                  } catch (_) {}
                  _killHighlight(ctx);
                  try {
                    final r = ctx.read<ReaderProvider>();
                    if (r.storyId != null) {
                      await ReadingProgressStore.setPage(r.storyId!, r.index);
                    }
                  } catch (_) {}
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                },
              ),
              _CircleIconButton(
                icon: Icons.volume_up,
                onTap: () => _showVolumeSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showVolumeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VolumeSheet(),
  );
}

class _VolumeSheet extends StatelessWidget {
  const _VolumeSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Consumer<TtsProvider>(
          builder: (_, tts, __) {
            final pct = (tts.volume * 100).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.volume_up, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Volume Narasi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textWidthBasis: TextWidthBasis.parent,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider.adaptive(
                  value: tts.volume,
                  onChanged: (v) => tts.setVolume(v),
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '$pct%',
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TextButton.icon(
                          onPressed: () => tts.setVolume(0.0),
                          icon: const Icon(Icons.volume_mute),
                          label: const Text('Bisukan'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TextButton.icon(
                          onPressed: () => tts.setVolume(1.0),
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Maks'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FilledButton.icon(
                          onPressed: () => tts.speak('Ini adalah uji suara.'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Uji suara'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({
    required this.panelExpanded,
    required this.onToggle,
    required this.textScroll,
    required this.autoReadVN,
    required this.onRequestEndSheet,
  });

  final bool panelExpanded;
  final VoidCallback onToggle;
  final ScrollController textScroll;
  final ValueNotifier<bool> autoReadVN;
  final VoidCallback onRequestEndSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    final double panelHeight = size.height * .40;

    // === Warna highlight adaptif (terlihat di light/dark) ===
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color hiBg = isDark
        ? cs.primaryContainer.withValues(alpha: 0.55) // lebih pekat di dark
        : cs.primary.withValues(alpha: 0.32); // sedikit lebih ringan di light

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: panelHeight,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 3,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Teks Halaman',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textWidthBasis: TextWidthBasis.parent,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: autoReadVN,
                        builder: (_, on, __) {
                          final c = on ? cs.primary : cs.onSurfaceVariant;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                                 autoReadVN.value = !on;
                                 final ctx = context; // cache
                                 final tts = ctx.read<TtsProvider>();
                                 final parent = ctx.findAncestorStateOfType<_ReaderScreenState>();
                              if (!autoReadVN.value) {
                                // dimatikan -> stop suara & highlight
                                try { await tts.stop(); } catch (_) {}
                                   try { await ctx.read<TtsCompatAdapter>().stop(); } catch (_) {}
                                   if (!ctx.mounted) return;
                                   _killHighlight(ctx);
                                return;
                              }
                              // dinyalakan -> mulai baca halaman aktif
                                 final r = ctx.read<ReaderProvider>();
                              if (!tts.speaking && r.pages.isNotEmpty) {
                                final text = cleanZW(
                                  r.pages[r.index].textPlain ?? '',
                                );
                                if (text.isNotEmpty) {
                                  parent?._cancelHighlightTimers();
                                  tts.active.value = const TextRange(
                                    start: 0,
                                    end: 0,
                                  );
                                  parent?._resetHighlight();
                                  parent?._resetUtteranceTiming();
                                  await tts.stop();
                                  if (!ctx.mounted) return;
                                  parent?._speakStartEpochMs =
                                      DateTime.now().millisecondsSinceEpoch;
                                  parent?._emaCps = kBaseCps;
                                  parent?._estDurMs =
                                      ((text.length / (parent._emaCps)) * 1000)
                                          .round();
                                  dlog(
                                    'speak() page=${context.read<ReaderProvider>().index + 1} len=${text.length} | "${shortStr(text)}"',
                                  );
                                  if (kUseSmoothFollow) {
                                    parent?._startSmoothFollow(text);
                                  }
                                  await tts.speak(text);
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    on
                                        ? Icons.auto_mode
                                        : Icons.auto_mode_outlined,
                                    size: 20,
                                    color: c,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    on ? 'Auto: ON' : 'Auto: OFF',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: c,
                                          fontWeight: on
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                _ControlsRow(onRequestEndSheet: onRequestEndSheet),
                const SizedBox(height: 4),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Consumer<ReaderProvider>(
                      builder: (_, r, __) {
                        if (r.pages.isEmpty) return const SizedBox();
                        final txt = cleanZW(r.pages[r.index].textPlain ?? '');

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!kTtsDebug) return;
                          dlog(
                            'page=${r.index + 1} ready len=${txt.length} first="${shortStr(txt)}"',
                          );
                          if (textScroll.hasClients) textScroll.jumpTo(0);
                        });

                        final normal = Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(height: 1.35);
                        final hi = normal.copyWith(
                          backgroundColor: hiBg,
                          fontWeight: FontWeight.w700,
                        );

                        final tts = context.read<TtsProvider>(); // read only

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.98, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Scrollbar(
                            key: ValueKey(r.index),
                            controller: textScroll,
                            child: SingleChildScrollView(
                              controller: textScroll,
                              padding: const EdgeInsets.only(bottom: 8),
                              physics: const ClampingScrollPhysics(),
                              child: ValueListenableBuilder<TextRange>(
                                valueListenable: tts.active,
                                builder: (_, range, __) {
                                  final s = range.start.clamp(0, txt.length);
                                  final e = range.end.clamp(0, txt.length);
                                  return RichText(
                                    text: TextSpan(
                                      style: normal,
                                      children: [
                                        if (s > 0)
                                          TextSpan(text: txt.substring(0, s)),
                                        if (e > s)
                                          TextSpan(
                                            text: txt.substring(s, e),
                                            style: hi,
                                          ),
                                        if (e < txt.length)
                                          TextSpan(text: txt.substring(e)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({required this.onRequestEndSheet});

  final VoidCallback onRequestEndSheet;

  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReaderProvider>();

    return Consumer<TtsProvider>(
      builder: (_, tts, __) {
        final page = r.pages.isEmpty ? null : r.pages[r.index];
        final text = cleanZW(page?.textPlain ?? '');

        Future<void> playCurrent() async {
          final parent = context.findAncestorStateOfType<_ReaderScreenState>();
          parent?._cancelHighlightTimers();
          tts.active.value = const TextRange(start: 0, end: 0);
          parent?._resetHighlight();
          parent?._resetUtteranceTiming();

          await tts.stop();
          if (text.isEmpty) return;

          parent?._speakStartEpochMs = DateTime.now().millisecondsSinceEpoch;
          parent?._emaCps = kBaseCps;
          parent?._estDurMs = ((text.length / (parent._emaCps)) * 1000).round();
          dlog(
            'speak() page=${context.read<ReaderProvider>().index + 1} len=${text.length} | "${shortStr(text)}"',
          );
          if (kUseSmoothFollow) parent?._startSmoothFollow(text);
          await tts.speak(text);
        }

        void afterPageChanged() {
          final parent = context.findAncestorStateOfType<_ReaderScreenState>();
          parent?._cancelHighlightTimers();
          tts.active.value = const TextRange(start: 0, end: 0);
          parent?._resetHighlight();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await tts.stop();
                afterPageChanged();
                r.prevPage();
                dlog('prevPage -> ${r.index}');
                try {
                  final sp = await SharedPreferences.getInstance();
                  if (r.storyId != null) {
                    await sp.setInt('last_story_id', r.storyId!);
                    await sp.setInt('last_page_index', r.index);
                  }
                } catch (_) {}
              },
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: tts.speakingVN,
              builder: (_, isSpeaking, __) {
                return IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (isSpeaking) {
                      await tts.stop();
                      _killHighlight(
                        context,
                      ); // <— stop highlight saat ditekan Stop
                    } else {
                      await playCurrent();
                    }
                  },
                  icon: Icon(
                    isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                );
              },
            ),
            IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                if (r.pages.isEmpty) return;

                final isLast = (r.index + 1) >= r.pages.length;

                // === PATCH: Matikan Auto Read saat user klik Next ===
                final parent = context
                    .findAncestorStateOfType<_ReaderScreenState>();
                if (parent != null) {
                  parent._autoRead.value = false; // <- Auto Read OFF
                }

                await tts.stop();
                afterPageChanged();

                if (isLast) {
                  try {
                    final sp = await SharedPreferences.getInstance();
                    if (r.storyId != null) {
                      await sp.setInt('last_story_id', r.storyId!);
                      await sp.setInt('last_page_index', r.index);
                    }
                  } catch (_) {}
                  onRequestEndSheet();
                  return;
                }

                r.nextPage();
                dlog('nextPage -> ${r.index}');
                try {
                  final sp = await SharedPreferences.getInstance();
                  if (r.storyId != null) {
                    await sp.setInt('last_story_id', r.storyId!);
                    await sp.setInt('last_page_index', r.index);
                  }
                } catch (_) {}
              },
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 42, color: cs.primary),
            const SizedBox(height: 10),
            Text(
              'Tidak ada halaman untuk cerita ini',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Coba pilih cerita lain atau periksa data halaman.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: cs.onSurface),
        ),
      ),
    );
  }
}
