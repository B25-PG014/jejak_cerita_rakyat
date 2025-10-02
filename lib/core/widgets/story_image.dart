// lib/core/widgets/story_image.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Pemakaian:
///   storyImage(story.coverAsset, fit: BoxFit.cover)
Widget storyImage(
  String? rawPath, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Alignment alignment = Alignment.center,
}) {
  final placeholder = Container(
    color: Colors.grey.shade300,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
  );

  if (rawPath == null) return placeholder;

  // Bersihkan spasi & kutip di awal/akhir
  var path = rawPath.trim();
  if ((path.startsWith('"') && path.endsWith('"')) ||
      (path.startsWith("'") && path.endsWith("'"))) {
    path = path.substring(1, path.length - 1).trim();
  }
  if (path.isEmpty) return placeholder;

  final lower = path.toLowerCase();

  // === URL ===
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return _optimizedNetwork(
      path,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: placeholder,
    );
  }

  // === Asset bundle ===
  if (lower.startsWith('assets/')) {
    return FutureBuilder<bool>(
      future: _assetExists(path),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (snap.data == true) {
          return _optimizedAsset(
            path,
            fit: fit,
            width: width,
            height: height,
            alignment: alignment,
            placeholder: placeholder,
          );
        }
        // fallback: kalau ternyata itu file lokal yang kebetulan diawali "assets/"
        final f = File(path);
        if (f.existsSync()) {
          return _optimizedFile(
            f,
            fit: fit,
            width: width,
            height: height,
            alignment: alignment,
            placeholder: placeholder,
          );
        }
        return placeholder;
      },
    );
  }

  // === File lokal (path absolut/relatif) ===
  try {
    final f = File(path);
    if (f.existsSync()) {
      return _optimizedFile(
        f,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        placeholder: placeholder,
      );
    }
  } catch (_) {
    // ignore
  }

  return placeholder;
}

Future<bool> _assetExists(String key) async {
  try {
    await rootBundle.load(key);
    return true;
  } catch (_) {
    return false;
  }
}

/// Versi Asset dengan LayoutBuilder + cacheWidth/Height
Widget _optimizedAsset(
  String asset, {
  required BoxFit fit,
  required double? width,
  required double? height,
  required Alignment alignment,
  required Widget placeholder,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final maxW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : (width ?? 200);
      final maxH = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : (height ?? maxW);
      final targetW = (maxW * dpr);
      final targetH = (maxH * dpr);
      final cw = targetW.isFinite ? targetW.round() : null;
      final ch = targetH.isFinite ? targetH.round() : null;

      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: cw,
        cacheHeight: ch,
        filterQuality: FilterQuality.medium, // hemat & tetap tajam
        errorBuilder: (_, __, ___) => placeholder,
      );
    },
  );
}

/// Versi File lokal dengan LayoutBuilder + cacheWidth/Height
Widget _optimizedFile(
  File file, {
  required BoxFit fit,
  required double? width,
  required double? height,
  required Alignment alignment,
  required Widget placeholder,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final maxW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : (width ?? 200);
      final maxH = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : (height ?? maxW);
      final targetW = (maxW * dpr);
      final targetH = (maxH * dpr);
      final cw = targetW.isFinite ? targetW.round() : null;
      final ch = targetH.isFinite ? targetH.round() : null;

      return Image.file(
        file,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: cw,
        cacheHeight: ch,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => placeholder,
      );
    },
  );
}

/// Versi Network dengan LayoutBuilder + cacheWidth/Height
Widget _optimizedNetwork(
  String url, {
  required BoxFit fit,
  required double? width,
  required double? height,
  required Alignment alignment,
  required Widget placeholder,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final maxW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : (width ?? 200);
      final maxH = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : (height ?? maxW);
      final targetW = (maxW * dpr);
      final targetH = (maxH * dpr);
      final cw = targetW.isFinite ? targetW.round() : null;
      final ch = targetH.isFinite ? targetH.round() : null;

      return Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: cw,
        cacheHeight: ch,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => placeholder,
      );
    },
  );
}
