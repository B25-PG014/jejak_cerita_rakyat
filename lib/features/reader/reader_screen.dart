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

class ReaderScreen extends StatefulWidget {
  final int id;
  const ReaderScreen({super.key, required this.id});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _textScroll = ScrollController();
  bool _panelExpanded = false;
  bool _openedOnce = false;
  final ValueNotifier<bool> _autoRead = ValueNotifier<bool>(false);

  // NEW: subscription selesai TTS → untuk auto-advance
  StreamSubscription<void>? _ttsDoneSub;

  @override
  void initState() {
    super.initState();
    // pastikan TTS sinopsis benar2 mati saat masuk reader
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

  // Precache image halaman berikutnya agar transisi lebih halus
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

      // Auto-scroll teks mengikuti progres TTS
      final tts = context.read<TtsProvider>();
      tts.onProgress = (txt, s, e, _) {
        tts.active.value = TextRange(start: s, end: e);
        if (!_textScroll.hasClients) return;
        final len = txt.isEmpty ? 1 : txt.length;
        final ratio = e / len;
        final max = _textScroll.position.maxScrollExtent;
        _textScroll.animateTo(
          ratio * max,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      };

      // NEW: Dengarkan selesai TTS → auto next page + speak lagi jika auto ON
      _ttsDoneSub = tts.onComplete.listen((_) async {
        if (!mounted) return;
        if (!_autoRead.value) return;

        final r = context.read<ReaderProvider>();
        if (r.pages.isEmpty) return;
        final hasNext = r.index + 1 < r.pages.length;
        if (!hasNext) return;

        r.nextPage();
        tts.active.value = const TextRange(start: 0, end: 0);

        final page = r.pages[r.index];
        final text = (page.textPlain ?? '').trim();
        if (text.isEmpty) return;

        await Future.delayed(const Duration(milliseconds: 200));
        await tts.stop();
        await tts.speak(text);
      });
    });
  }

  @override
  void dispose() {
    _ttsDoneSub?.cancel();
    _textScroll.dispose();
    super.dispose();
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
                // =================== ILUSTRASI (selalu tampak di belakang panel) ===================
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

                      // Ambil baseDir dari provider (wajib: assets/stories/[judul-cerita]/
                      final baseDir = _sanitizeBaseDir(r.storyDir);

                      // Siapkan precache untuk halaman berikutnya
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
                          key: ValueKey(r.index), // kunci berbeda tiap halaman
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

                // =================== PANEL TEKS (overlay di bawah) ===================
                _ReadingPanel(
                  panelExpanded: _panelExpanded,
                  onToggle: () =>
                      setState(() => _panelExpanded = !_panelExpanded),
                  textScroll: _textScroll,
                  autoReadVN: _autoRead,
                ),

                // bayangan lembut di bawah panel supaya kontras
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
                            color: Colors.black.withValues(alpha: .25),
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

/// Loader gambar yang "tahan banting":
/// - URL -> network
/// - Asset relatif: diprefix dengan baseDir: assets/stories/[judul-cerita]/
/// - Jika gagal -> placeholder.
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

    // kalau path relatif (mis. "p2.png" atau "img/p2.png"), prefix dengan baseDir
    final b = baseDir.endsWith('/') ? baseDir : '$baseDir/';
    if (clean.startsWith('/')) return '$b${clean.substring(1)}';
    return '$b$clean';
  }

  Future<String?> _resolveAsset(String rawWithBase) async {
    // Coba langsung
    try {
      await rootBundle.load(rawWithBase);
      return rawWithBase;
    } catch (_) {}

    // Kandidat cadangan (lebih konservatif)
    final base = rawWithBase;
    final List<String> candidates = [
      base,
      if (!base.startsWith('assets/')) 'assets/$base',
    ];

    for (final c in candidates) {
      try {
        await rootBundle.load(c);
        return c; // ketemu
      } catch (_) {
        /* lanjut */
      }
    }
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
      color: cs.surface.withValues(alpha: .15),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 42,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Top bar tombol bulat gaya glass
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
              // stop TTS (aman dipanggil walau tidak sedang bicara)
              try {
                await context.read<TtsProvider>().stop();
              } catch (_) {}
              try {
                await context.read<TtsCompatAdapter>().stop();
              } catch (_) {}
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.settings,
                onTap: () async {
                  // Pastikan TTS berhenti sebelum masuk ke halaman Settings
                  try {
                    await context.read<TtsProvider>().stop();
                  } catch (_) {}
                  try {
                    await context.read<TtsCompatAdapter>().stop();
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed('/settings');
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

/// Bottom sheet pengaturan volume
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
          color: cs.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: .18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
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
                    // Title dibuat Expanded agar tidak overflow saat text scale besar
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
                // Tombol-tombol dibuat responsif agar tidak overflow di text scale besar
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

/// Panel teks: collapsed = ringkas (preview), expanded = scroll penuh
class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({
    required this.panelExpanded,
    required this.onToggle,
    required this.textScroll,
    required this.autoReadVN,
  });

  final bool panelExpanded;
  final VoidCallback onToggle;
  final ScrollController textScroll;
  final ValueNotifier<bool> autoReadVN;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    const double panelMinBase = 160.0; // tinggi dasar saat collapsed
    final double panelMax = size.height * .40; // tinggi saat expanded

    // ==== FIX: tinggi collapsed adaptif sesuai skala teks + bantalan ekstra ====
    final double textScale = MediaQuery.of(context).textScaler.scale(1.0);
    // Tambah headroom ±90px per kenaikan skala + cushion 14px, dibatasi < panelMax
    final double collapsedHeight = math.max(
      panelMinBase + 14.0,
      math.min(panelMax - 4.0, panelMinBase + 14.0 + (textScale - 1.0) * 90.0),
    );

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: panelExpanded ? panelMax : collapsedHeight,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: .2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
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
                // Header panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 3,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: .25),
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

                      // ======= INDICATOR + TOGGLE AUTO BACA =======
                      ValueListenableBuilder<bool>(
                        valueListenable: autoReadVN,
                        builder: (_, on, __) {
                          final c = on ? cs.primary : cs.onSurfaceVariant;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              autoReadVN.value = !on;

                              // NEW: kalau baru dinyalakan & belum bicara, mulai bacakan halaman aktif
                              if (autoReadVN.value) {
                                final r = context.read<ReaderProvider>();
                                final tts = context.read<TtsProvider>();
                                if (!tts.speaking && r.pages.isNotEmpty) {
                                  final text =
                                      (r.pages[r.index].textPlain ?? '').trim();
                                  if (text.isNotEmpty) {
                                    await tts.stop();
                                    await tts.speak(text);
                                  }
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
                      // Tombol expand/collapse
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onToggle,
                        icon: Icon(
                          panelExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                // Kontrol
                const _ControlsRow(),
                const SizedBox(height: 4), // diperkecil agar aman
                // === Konten teks ===
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Consumer<ReaderProvider>(
                      builder: (_, r, __) {
                        if (r.pages.isEmpty) return const SizedBox();
                        final txt = r.pages[r.index].textPlain ?? '';

                        // reset scroll ke atas saat pindah halaman
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (textScroll.hasClients) textScroll.jumpTo(0);
                        });

                        if (!panelExpanded) {
                          // PREVIEW
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              txt,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.copyWith(height: 1.35),
                            ),
                          );
                        }

                        // FULL SCROLL
                        final normal = Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(height: 1.35);
                        final hi = normal.copyWith(
                          backgroundColor: cs.primary.withValues(alpha: .25),
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
                            key: ValueKey(r.index), // kunci per-halaman
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

/// Tombol kontrol narasi & page
class _ControlsRow extends StatelessWidget {
  const _ControlsRow();

  @override
  Widget build(BuildContext context) {
    // DENGARKAN ReaderProvider agar ikut rebuild saat index/page berubah
    final r = context.watch<ReaderProvider>();

    return Consumer<TtsProvider>(
      builder: (_, tts, __) {
        final page = r.pages.isEmpty ? null : r.pages[r.index];
        final text = (page?.textPlain ?? '').trim();

        Future<void> playCurrent() async {
          await tts.stop(); // pastikan tidak overlap
          if (text.isEmpty) return;
          await tts.speak(text); // speak halaman TERKINI
        }

        void afterPageChanged() {
          tts.active.value = const TextRange(
            start: 0,
            end: 0,
          ); // kosongkan highlight
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.outlined(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await tts.stop();
                r.prevPage();
                afterPageChanged();
              },
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            // === Play/Stop sinkron dengan speakingVN (tidak diubah) ===
            ValueListenableBuilder<bool>(
              valueListenable: tts.speakingVN,
              builder: (_, isSpeaking, __) {
                return IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (isSpeaking) {
                      await tts.stop();
                    } else {
                      await tts.stop(); // antisipasi overlap
                      if (text.isNotEmpty) await tts.speak(text);
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
                await tts.stop();
                r.nextPage();
                afterPageChanged();
              },
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        );
      },
    );
  }
}

/// Empty state bertema glass
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
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

/// Tombol bulat netral (glass)
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
