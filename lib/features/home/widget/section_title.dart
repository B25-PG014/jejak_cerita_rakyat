import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Judul section minimal tanpa ikon.
/// - Font display elegan (DM Serif Display)
/// - Stroke halus agar terbaca di bg bergambar
/// - Underline gradasi emas (opsional, width bisa diatur)
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.caption,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.showUnderline = true,
    this.underlineWidth, // if null -> auto
  });

  final String title;
  final String? caption;
  final EdgeInsets padding;
  final bool showUnderline;
  final double? underlineWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tipografi title
    final titleStyle = GoogleFonts.dmSerifDisplay(
      fontSize: 22,
      height: 1.1,
      letterSpacing: .3,
      color: cs.onSurface,
    );

    // Stroke tipis supaya kebaca di bg
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.1 : 0.9
      ..color = isDark
          ? Colors.white.withOpacity(.20)
          : Colors.black.withOpacity(.16);

    // Auto width underline: ~36% dari layar (80..180 px)
    final screenW = MediaQuery.of(context).size.width;
    final autoW = math.max(
      80.0,
      math.min(180.0, screenW * 0.36),
    ); // clamp 80..180
    final ulWidth = underlineWidth ?? autoW;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title dengan stroke + fill (dua layer)
          Stack(
            children: [
              Text(title, style: titleStyle.copyWith(foreground: strokePaint)),
              Text(title, style: titleStyle),
            ],
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withOpacity(.60),
              ),
            ),
          ],
          if (showUnderline) ...[
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: ulWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5E08C), Color(0xFFE3B85A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
