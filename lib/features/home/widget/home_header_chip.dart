import 'dart:ui';
import 'package:flutter/material.dart';

/// Header bergaya glass + aksen gold.
/// Tetap menampilkan "Jejak Cerita Rakyat" + tombol Settings & Search di dalam kartu.
class HomeHeaderChip extends StatelessWidget {
  const HomeHeaderChip({
    super.key,
    this.onSettingsTap,
    this.onSearchTap,
    this.showTagline = true,
  });

  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360; // sembunyikan tagline kalau layar kecil

    return _GlassCard(
      borderRadius: 18,
      blur: 8,
      // seluruh header dalam satu kartu, action di kanan
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ikon aksen gold
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF5E08C), Color(0xFFE3B85A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: Colors.brown.shade800,
              ),
            ),
            const SizedBox(width: 12),

            // judul
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jejak Cerita',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                  _GradientText(
                    'Rakyat',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5E08C), Color(0xFFE3B85A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  if (showTagline && !compact)
                    Text(
                      'Jelajahi warisan Nusantara',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface.withOpacity(.60),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // actions di dalam kartu (glass circle)
            _CircleAction(
              icon: Icons.settings_rounded,
              onTap:
                  onSettingsTap ??
                  () => Navigator.of(context).pushNamed('/settings'),
            ),
            const SizedBox(width: 8),
            _CircleAction(
              icon: Icons.search_rounded,
              onTap:
                  onSearchTap ??
                  () => Navigator.of(context).pushNamed('/search'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu glass: blur + gradient, dengan stroke di LAPISAN ATAS (fix border putus di dark mode)
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderRadius = 16,
    this.blur = 6,
  });

  final Widget child;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stroke = (Theme.of(context).brightness == Brightness.dark)
        ? Colors.white.withOpacity(.18)
        : Colors.black.withOpacity(.06); // kontras pas di 2 mode

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // layer blur + gradient
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.surface.withOpacity(.78),
                      cs.surface.withOpacity(.55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              ),
            ),
            // *** stroke di ATAS blur (bukan di dalam) -> tidak putus di dark mode
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: stroke, width: 1.1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol bulat kaca dengan outline tipis (nyatu dengan kartu)
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surface.withOpacity(.65),
          border: Border.all(color: Colors.white.withOpacity(.22), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.18),
              offset: const Offset(0, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: cs.onSurface),
      ),
    );
  }
}

/// Teks dengan gradient (untuk kata "Rakyat")
class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.gradient, required this.style});

  final String text;
  final Gradient gradient;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style),
    );
  }
}
