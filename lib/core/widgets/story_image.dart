// lib/core/widgets/story_image.dart
import 'package:flutter/material.dart';

/// Helper untuk menampilkan cover/story image.
/// - Bisa sumber asset atau network (kalau kamu pakai).
/// - Menyediakan fallback placeholder.
/// - Mendukung gaplessPlayback untuk kurangi flicker saat rebuild.
Widget storyImage(
  String? src, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  bool gaplessPlayback = false,
  String placeholder = 'assets/images/covers/default_cover.png',
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  if (src == null || src.isEmpty) {
    return Image.asset(
      placeholder,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
    );
  }

  // Deteksi simple: kalau string mengandung "http" anggap network, selain itu asset
  final isNetwork = src.startsWith('http://') || src.startsWith('https://');

  if (isNetwork) {
    return Image.network(
      src,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      errorBuilder: (_, __, ___) => Image.asset(
        placeholder,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
      ),
    );
  } else {
    return Image.asset(
      src,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      errorBuilder: (_, __, ___) => Image.asset(
        placeholder,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
      ),
    );
  }
}
