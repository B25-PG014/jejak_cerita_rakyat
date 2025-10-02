// lib/features/reader/reader_screen.dart
import 'dart:async';
import 'dart:ui' show ImageFilter, TextRange;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/providers/reader_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';

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

  // Precache image halaman berikutnya agar transisi lebih halus
  void _precacheNextPage(BuildContext context, String? nextPath) {
    if (nextPath == null) return;
    final p = nextPath.trim();
    if (p.isEmpty) return;

    // Pilih ImageProvider sesuai sumber (URL vs asset)
    ImageProvider provider;
    if (p.startsWith('http://') || p.startsWith('https://')) {
      provider = NetworkImage(p);
    } else {
      provider = AssetImage(p);
    }

    // Jalankan setelah frame ini supaya context sudah stabil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(provider, context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedOnce) return;
    _openedOnce = true;

    // Jalankan setelah widget attach supaya provider pasti ada.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    });
  }

  @override
  void dispose() {
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

                      // Siapkan precache untuk halaman berikutnya
                      final String? nextAsset = (r.index + 1 < r.pages.length)
                          ? r.pages[r.index + 1].imageAsset
                          : null;
                      _precacheNextPage(context, nextAsset);

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
                              child: _SafeStoryImage(path: page.imageAsset),
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
                            color: Colors.black.withOpacity(.25),
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
/// - Asset relatif: coba beberapa kandidat path; jika gagal -> placeholder.
class _SafeStoryImage extends StatelessWidget {
  const _SafeStoryImage({required this.path});
  final String? path;

  bool _looksLikeUrl(String p) =>
      p.startsWith('http://') || p.startsWith('https://');

  Future<String?> _resolveAsset(String raw) async {
    final base = raw.trim();
    final List<String> candidates = [
      base,
      if (!base.startsWith('assets/')) ...[
        'assets/$base',
        'assets/stories/$base',
        'assets/images/$base',
        'assets/images/stories/$base',
      ],
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
    final p = (path ?? '').trim();
    if (p.isEmpty) return _placeholder(context);

    if (_looksLikeUrl(p)) {
      return Image.network(
        p,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveAsset(p),
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
      color: cs.surface.withOpacity(.15),
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
            onTap: () => Navigator.of(context).pop(),
          ),
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.settings,
                onTap: () => Navigator.of(context).pushNamed('/settings'),
              ),
              // === Tombol speaker → buka pengaturan volume ===
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
          color: cs.surface.withOpacity(.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.22),
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
                    Text(
                      'Volume Narasi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => tts.setVolume(0.0),
                      icon: const Icon(Icons.volume_mute),
                      label: const Text('Bisukan'),
                    ),
                    TextButton.icon(
                      onPressed: () => tts.setVolume(1.0),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Maks'),
                    ),
                    FilledButton.icon(
                      onPressed: () => tts.speak('Ini adalah uji suara.'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Uji suara'),
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

/// Panel teks: min height besar agar tidak overflow; overlay di bawah
/// Panel teks: collapsed = ringkas (preview), expanded = scroll penuh
class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({
    required this.panelExpanded,
    required this.onToggle,
    required this.textScroll,
  });

  final bool panelExpanded;
  final VoidCallback onToggle;
  final ScrollController textScroll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    const double panelMin = 160.0; // tinggi saat collapsed
    final double panelMax = size.height * .40; // tinggi saat expanded

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: panelExpanded ? panelMax : panelMin,
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.28),
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
                          color: cs.onSurface.withOpacity(.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Teks Halaman',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
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
                const SizedBox(height: 8),

                // === Konten teks ===
                // Collapsed: preview pendek (2–3 baris)
                // Expanded : scroll penuh + highlight
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Consumer<ReaderProvider>(
                      builder: (_, r, __) {
                        if (r.pages.isEmpty) return const SizedBox();
                        final txt = r.pages[r.index].textPlain ?? '';

                        if (!panelExpanded) {
                          // PREVIEW — kecil agar panel bisa benar2 mengecil
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

                        // FULL SCROLL — saat expanded
                        final normal = Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(height: 1.35);
                        final hi = normal.copyWith(
                          backgroundColor: cs.primary.withOpacity(.25),
                          fontWeight: FontWeight.w700,
                        );

                        final tts = context
                            .read<
                              TtsProvider
                            >(); // read (bukan watch) agar panel tidak rebuild saat progress

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
                              physics:
                                  const ClampingScrollPhysics(), // 4.3 (lihat di bawah)
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
    final r = context.read<ReaderProvider>();

    return Consumer<TtsProvider>(
      builder: (_, tts, __) {
        final page = r.pages.isEmpty ? null : r.pages[r.index];
        final text = page?.textPlain ?? '';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.outlined(
              onPressed: () {
                tts.stop();
                r.prevPage();
              },
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton.outlined(
              onPressed: () {
                if (tts.ready) {
                  tts.speak(text);
                } else {
                  tts.stop();
                }
              },
              icon: Icon(
                tts.ready ? Icons.play_arrow_rounded : Icons.stop_rounded,
              ),
            ),
            IconButton.outlined(
              onPressed: () {
                tts.stop();
                r.nextPage();
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
          color: cs.surface.withOpacity(.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.22),
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
            color: cs.surface.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
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
