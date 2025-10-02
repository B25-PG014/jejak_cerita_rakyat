// lib/features/home/home_screen.dart
import 'dart:ui' show Offset;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:jejak_cerita_rakyat/features/detail/detail_screen.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';

import 'widget/home_header_chip.dart';
import 'widget/home_bottom_actions.dart';
import 'widget/province_popup.dart';
import 'widget/fluid_story_card.dart';
import 'widget/section_title.dart';

/// Koordinat relatif fallback (berbasis viewBox SVG)
const Map<String, Offset> kProvinceCenters = {
  // Sumatera
  'Aceh': Offset(0.060, 0.375),
  'Sumatera Utara': Offset(0.102, 0.395),
  'Sumatera Barat': Offset(0.152, 0.425),
  'Riau': Offset(0.180, 0.445),
  'Kepulauan Riau': Offset(0.195, 0.485),
  'Jambi': Offset(0.195, 0.475),
  'Sumatera Selatan': Offset(0.205, 0.515),
  'Bengkulu': Offset(0.170, 0.505),
  'Lampung': Offset(0.215, 0.565),
  'Bangka Belitung': Offset(0.230, 0.520),

  // Jawa
  'Banten': Offset(0.270, 0.585),
  'DKI Jakarta': Offset(0.290, 0.585),
  'Jawa Barat': Offset(0.305, 0.595),
  'Jawa Tengah': Offset(0.345, 0.600),
  'DI Yogyakarta': Offset(0.355, 0.615),
  'Jawa Timur': Offset(0.385, 0.605),

  // Bali & Nusa
  'Bali': Offset(0.415, 0.615),
  'Nusa Tenggara Barat': Offset(0.445, 0.625),
  'Nusa Tenggara Timur': Offset(0.495, 0.640),

  // Kalimantan
  'Kalimantan Barat': Offset(0.305, 0.475),
  'Kalimantan Tengah': Offset(0.350, 0.495),
  'Kalimantan Selatan': Offset(0.365, 0.535),
  'Kalimantan Timur': Offset(0.405, 0.485),
  'Kalimantan Utara': Offset(0.385, 0.455),

  // Sulawesi
  'Sulawesi Utara': Offset(0.515, 0.505),
  'Gorontalo': Offset(0.505, 0.520),
  'Sulawesi Tengah': Offset(0.505, 0.540),
  'Sulawesi Barat': Offset(0.490, 0.560),
  'Sulawesi Selatan': Offset(0.505, 0.575),
  'Sulawesi Tenggara': Offset(0.535, 0.585),

  // Maluku & Papua
  'Maluku': Offset(0.600, 0.610),
  'Maluku Utara': Offset(0.600, 0.560),
  'Papua Barat': Offset(0.670, 0.545),
  'Papua': Offset(0.735, 0.545),
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;
  static const double _cardHeight = 340;
  static const double _cardRadiusMask = 22;

  // Besarkan map di sini
  static const double _mapHeight = 320;

  double? _svgAspect; // W/H dari viewBox SVG
  bool _debugTap = false; // toggle via long-press

  // kick sekali setelah layout siap (mencegah pin di (0,0) di frame pertama)
  bool _didKick = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StoryProvider>().loadProvincePins();
      await _loadSvgAspect();
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSvgAspect() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/svg/map_indonesia_simplified.svg',
      );

      final vb = RegExp(
        r'''viewBox\s*=\s*["']\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)\s*["']''',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);

      if (vb != null) {
        final w = double.tryParse(vb.group(1)!);
        final h = double.tryParse(vb.group(2)!);
        if (w != null && h != null && w > 0 && h > 0) {
          setState(() => _svgAspect = w / h);
          return;
        }
      }

      final wAttr = RegExp(
        r'''width\s*=\s*["']\s*([\d.]+)\s*["']''',
        caseSensitive: false,
      ).firstMatch(raw);
      final hAttr = RegExp(
        r'''height\s*=\s*["']\s*([\d.]+)\s*["']''',
        caseSensitive: false,
      ).firstMatch(raw);

      if (wAttr != null && hAttr != null) {
        final w = double.tryParse(wAttr.group(1)!);
        final h = double.tryParse(hAttr.group(1)!);
        if (w != null && h != null && w > 0 && h > 0) {
          setState(() => _svgAspect = w / h);
          return;
        }
      }

      setState(() => _svgAspect = 16 / 9);
    } catch (_) {
      setState(() => _svgAspect = 16 / 9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();
    final stories = provider.stories;
    final featured = stories.take(10).toList();

    final currentStory = (featured.isNotEmpty)
        ? featured[_current.clamp(0, featured.length - 1)]
        : null;

    final contentAspect = _svgAspect ?? (16 / 9);

    // kick satu frame setelah rasio sudah ada → memastikan ukuran map final
    if (_svgAspect != null && !_didKick) {
      _didKick = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    final mapKey = ValueKey(
      'map-${currentStory?.id}-${_svgAspect?.toStringAsFixed(6) ?? 'null'}',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // background
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: HomeHeaderChip(),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 2),
                const SectionTitle(
                  title: 'Cerita Pilihan',
                  showUnderline: false,
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      if (featured.isNotEmpty)
                        SizedBox(
                          height: _cardHeight,
                          child: CarouselSlider.builder(
                            itemCount: featured.length,
                            options: CarouselOptions(
                              height: _cardHeight,
                              viewportFraction: 0.68,
                              padEnds: true,
                              enlargeCenterPage: true,
                              enlargeStrategy: CenterPageEnlargeStrategy.height,
                              enlargeFactor: 0.42,
                              onPageChanged: (i, _) =>
                                  setState(() => _current = i),
                            ),
                            itemBuilder: (ctx, i, _) {
                              final it = featured[i];
                              final isSelected = i == _current;
                              return AnimatedPadding(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: isSelected ? 0 : 18,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    FluidStoryCard(story: it),
                                    if (!isSelected)
                                      const _GoldBorderMask(
                                        radius: _cardRadiusMask,
                                      ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    DetailScreen(data: it),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 16),

                      // MAP (hanya render setelah _svgAspect siap)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _svgAspect == null
                            ? SizedBox(
                                height: _mapHeight,
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: _mapHeight,
                                child: KeyedSubtree(
                                  key: mapKey,
                                  child: _MapCard(
                                    builder: (context) => Stack(
                                      children: [
                                        Positioned.fill(
                                          child: SvgPicture.asset(
                                            'assets/svg/map_indonesia_simplified.svg',
                                            fit: BoxFit.contain,
                                          ),
                                        ),

                                        if (currentStory != null)
                                          Positioned.fill(
                                            child: FutureBuilder<List<ProvincePin>>(
                                              key: ValueKey<int>(
                                                currentStory.id,
                                              ),
                                              future: context
                                                  .read<StoryProvider>()
                                                  .pinsForStoryId(
                                                    currentStory.id,
                                                  ),
                                              builder: (context, snap) {
                                                if (snap.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const SizedBox.shrink();
                                                }
                                                final pins =
                                                    snap.data ??
                                                    const <ProvincePin>[];

                                                // Pakai layer adaptif: hitung letterbox sekali,
                                                // dan gunakan fallback koordinat bila perlu.
                                                return _PinsLayerAdaptive(
                                                  contentAspect: contentAspect,
                                                  pins: pins.map((p) {
                                                    final off =
                                                        kProvinceCenters[p
                                                            .name];
                                                    final x =
                                                        (off?.dx ?? p.xRel)
                                                            .clamp(0.0, 1.0) -
                                                        0.099;
                                                    final y =
                                                        (off?.dy ?? p.yRel)
                                                            .clamp(0.0, 1.0) -
                                                        0.28;
                                                    return (p.name, x, y);
                                                  }).toList(),
                                                  showNameLabel:
                                                      true, // selalu tampilkan nama
                                                  showDebugLabel:
                                                      _debugTap, // tampilkan koordinat hanya saat debug
                                                  onTapPin: (name) {
                                                    showProvincePopup(
                                                      context: context,
                                                      province: name,
                                                      items: [currentStory],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),

                                        // HIDDEN DEBUG: long-press area peta untuk toggle overlay debug
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onLongPress: () => setState(() {
                                              _debugTap = !_debugTap;
                                            }),
                                          ),
                                        ),

                                        if (_debugTap)
                                          Positioned.fill(
                                            child: _TapToRelOverlayAdaptive(
                                              contentAspect: contentAspect,
                                              onRelTap: (xr, yr) =>
                                                  _copyAndToast(xr, yr),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const HomeBottomActions(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyAndToast(double x, double y) {
    final txt =
        '"x_rel": ${x.toStringAsFixed(4)}, "y_rel": ${y.toStringAsFixed(4)}';
    Clipboard.setData(ClipboardData(text: txt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $txt'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _GoldBorderMask extends StatelessWidget {
  const _GoldBorderMask({this.radius = 22});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: surface, width: 2.0),
          ),
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surfaceVariant.withOpacity(0.35),
                  cs.surfaceVariant.withOpacity(0.10),
                ],
              ),
            ),
          ),
          Container(color: cs.surface.withOpacity(0.08)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          builder(context),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layer yang menghitung letterbox sekali, lalu tempatkan banyak pin
class _PinsLayerAdaptive extends StatelessWidget {
  final double contentAspect;
  final List<(String name, double x, double y)> pins; // 0..1
  final bool showNameLabel; // tampilkan nama provinsi (tanpa x,y)
  final bool showDebugLabel; // tampilkan x,y (debug mode)
  final void Function(String name) onTapPin;

  const _PinsLayerAdaptive({
    required this.contentAspect,
    required this.pins,
    required this.showNameLabel,
    required this.showDebugLabel,
    required this.onTapPin,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final W = c.maxWidth;
        final H = c.maxHeight;
        if (W <= 0 || H <= 0) return const SizedBox.shrink();

        final boxAspect = W / H;
        double innerW = W, innerH = H, offX = 0, offY = 0;

        if (boxAspect > contentAspect) {
          innerH = H;
          innerW = H * contentAspect;
          offX = (W - innerW) / 2;
        } else if (boxAspect < contentAspect) {
          innerW = W;
          innerH = W / contentAspect;
          offY = (H - innerH) / 2;
        }

        return Stack(
          children: [
            for (final (name, x, y) in pins)
              Positioned(
                left: offX + x * innerW - 14,
                top: offY + y * innerH - 24,
                child: GestureDetector(
                  onTap: () => onTapPin(name),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showNameLabel)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.90),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      if (showDebugLabel)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '(x:${x.toStringAsFixed(3)}, y:${y.toStringAsFixed(3)})',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      Icon(
                        Icons.location_on_rounded,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TapToRelOverlayAdaptive extends StatelessWidget {
  final double contentAspect;
  final void Function(double xRel, double yRel) onRelTap;

  const _TapToRelOverlayAdaptive({
    required this.contentAspect,
    required this.onRelTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final W = c.maxWidth, H = c.maxHeight;
        final boxAspect = W / H;
        double innerW = W, innerH = H, offX = 0, offY = 0;

        if (boxAspect > contentAspect) {
          innerH = H;
          innerW = H * contentAspect;
          offX = (W - innerW) / 2;
        } else if (boxAspect < contentAspect) {
          innerW = W;
          innerH = W / contentAspect;
          offY = (H - innerH) / 2;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final lx = (d.localPosition.dx - offX).clamp(0.0, innerW);
            final ly = (d.localPosition.dy - offY).clamp(0.0, innerH);
            final xr = (lx / innerW).clamp(0.0, 1.0);
            final yr = (ly / innerH).clamp(0.0, 1.0);
            onRelTap(xr, yr);
          },
          child: Container(color: Colors.transparent),
        );
      },
    );
  }
}
