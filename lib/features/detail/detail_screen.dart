import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/core/widgets/story_image.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_provider.dart';
import 'package:jejak_cerita_rakyat/providers/tts_compat_adapter.dart';

class DetailScreen extends StatelessWidget {
  final StoryItem data;
  const DetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // === background sama seperti Home ===
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),
          PopScope(
            onPopInvokedWithResult: (didPop, result) async {
              // ekstra proteksi agar TTS sinopsis tidak bocor saat halaman ditutup
              try {
                final tts = context.read<TtsProvider>();
                await Future.any([
                  tts.stop(),
                  context.read<TtsCompatAdapter>().stop(),
                  Future.delayed(const Duration(milliseconds: 250)),
                ]);
              } catch (_) {}
            },
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  // ===== Cover =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _GoldGlassCard(
                        radius: 18,
                        strokeWidth: 2.2,
                        child: AspectRatio(
                          aspectRatio: 16 / 11,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: storyImage(
                                  data.coverAsset,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // gradient bawah untuk keterbacaan
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 84,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: .35),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // back button (glass circle)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: _GlassCircleButton(
                                  icon: Icons.arrow_back_rounded,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ===== Judul + metadata (compact) =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GlassCard(
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 24,
                                height: 1.1,
                                letterSpacing: .3,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Jumlah Halaman: ${data.pageCount}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: cs.onSurface.withValues(alpha: .8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== Sticky Action Bar (pinned) =====
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyActions(
                      minExtentHeight: 64,
                      maxExtentHeight: 74,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _PrimaryGlassButton(
                                  icon: Icons.menu_book_rounded,
                                  label: 'Mulai Membaca',
                                  onTap: () async {
                                    // TODO: push ke reader bila tersedia:
                                    try {
                                      final tts = context.read<TtsProvider>();
                                      // tunggu sebentar supaya engine benar2 stop, tapi jangan bikin nge-freeze
                                      await Future.any([
                                        tts.stop(),
                                        context.read<TtsCompatAdapter>().stop(),
                                        Future.delayed(
                                          const Duration(milliseconds: 250),
                                        ), // timeout kecil
                                      ]);
                                    } catch (_) {}

                                    if (!context.mounted) return;
                                    await Navigator.of(
                                      context,
                                    ).pushNamed('/reader', arguments: data.id);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Consumer<TtsProvider>(
                                  builder: (context, tts, _) {
                                    final playing = tts.speaking;
                                    return _PrimaryGlassButton(
                                      icon: playing
                                          ? Icons.stop
                                          : Icons.play_arrow_rounded,
                                      label: playing
                                          ? 'Berhenti'
                                          : 'Dengarkan Narasi',
                                      onTap: () {
                                        if (playing) {
                                          tts.stop();
                                        } else if ((data.synopsis ?? '')
                                            .isNotEmpty) {
                                          tts.speak(data.synopsis!);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ===== Sinopsis (lebih padat) =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _GlassCard(
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sinopsis',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.synopsis ?? '-',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== Spacer kecil biar tidak mentok tombol gesture nav =====
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// Sticky header delegate
/// =======================
class _StickyActions extends SliverPersistentHeaderDelegate {
  final double minExtentHeight;
  final double maxExtentHeight;
  final WidgetBuilder builder;

  _StickyActions({
    required this.minExtentHeight,
    required this.maxExtentHeight,
    required this.builder,
  });

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder(context);
  }

  @override
  bool shouldRebuild(covariant _StickyActions oldDelegate) {
    return oldDelegate.minExtentHeight != minExtentHeight ||
        oldDelegate.maxExtentHeight != maxExtentHeight ||
        oldDelegate.builder != builder;
  }
}

/// =======================
/// Shared glass components
/// =======================

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surface.withValues(alpha: .75),
                  cs.surface.withValues(alpha: .50),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .20),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GoldGlassCard extends StatelessWidget {
  const _GoldGlassCard({
    required this.child,
    this.radius = 16,
    this.strokeWidth = 2,
  });

  final Widget child;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          _GlassCard(radius: radius, padding: EdgeInsets.zero, child: child),
          // GOLD STROKE pakai painter → tidak “putus” di dark mode
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RoundedRectBorderPainter(
                  color: const Color(0xFFE3B85A),
                  radius: radius,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedRectBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  _RoundedRectBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RoundedRectBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: cs.surface.withValues(alpha: .55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: .22),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 22, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryGlassButton extends StatelessWidget {
  const _PrimaryGlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: cs.primary.withValues(alpha: .18),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .20),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: cs.onSurface),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
