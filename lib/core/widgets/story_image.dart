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
  final hasPath = (src != null && src.trim().isNotEmpty);
  final safePath = hasPath
      ? src.trim()
      : 'assets/images/covers/default_cover.png';
  if (src == null || src.isEmpty) {
    // Downscale cerdas sesuai layar untuk hemat RAM/GPU di device low-end
    final mq = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? MediaQueryData.fromView(
            WidgetsBinding.instance.platformDispatcher.views.first,
          )
        : null;
    final dpr = (mq?.devicePixelRatio ?? 2.0).clamp(1.0, 3.0);
    final logicalW = (mq?.size.width ?? 360.0);
    final targetW = (logicalW * dpr).toInt();
    final cacheW = targetW.clamp(480, 2048);

    return Image.asset(
      safePath,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      // Downscale agar decode lebih ringan, tetap tajam di layar
      cacheWidth: cacheW,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/covers/default_cover.png',
        fit: fit,
        alignment: alignment,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
        cacheWidth: cacheW,
      ),
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
