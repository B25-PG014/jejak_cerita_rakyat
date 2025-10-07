import 'dart:ui' show Offset, Rect;
import 'package:flutter/services.dart' show rootBundle;

/// ======== Helpers: numbers & viewBox ========

double? _parseNum(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim();
  final normalized =
      RegExp(r'^[+\-]?\d+(\.\d+)?([eE][+\-]?\d+)?').stringMatch(cleaned) ??
      cleaned.replaceAll(RegExp(r'[^\d.\-+eE]'), '');
  return double.tryParse(normalized);
}

double? _parsePercent(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (!s.endsWith('%')) return null;
  final numPart = s.substring(0, s.length - 1).trim();
  final v = double.tryParse(numPart);
  return (v == null) ? null : v / 100.0;
}

Rect _parseViewBoxOrFallback(String raw) {
  final m = RegExp(
    "viewBox\\s*=\\s*['\"]\\s*([\\-\\d.]+)\\s+([\\-\\d.]+)\\s+([\\-\\d.]+)\\s+([\\-\\d.]+)\\s*['\"]",
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(raw);

  if (m != null) {
    final minX = double.tryParse(m.group(1)!) ?? 0.0;
    final minY = double.tryParse(m.group(2)!) ?? 0.0;
    final w = double.tryParse(m.group(3)!) ?? 0.0;
    final h = double.tryParse(m.group(4)!) ?? 0.0;
    return Rect.fromLTWH(minX, minY, w, h);
  }

  final wAttr = RegExp(
    "width\\s*=\\s*['\"]\\s*([\\-\\d.]+)\\s*['\"]",
    caseSensitive: false,
  ).firstMatch(raw);
  final hAttr = RegExp(
    "height\\s*=\\s*['\"]\\s*([\\-\\d.]+)\\s*['\"]",
    caseSensitive: false,
  ).firstMatch(raw);

  final w = _parseNum(wAttr?.group(1)) ?? 1000.0;
  final h = _parseNum(hAttr?.group(1)) ?? 1000.0;
  return Rect.fromLTWH(0, 0, w, h);
}

String? _getAttr(String tag, String name) {
  final rx = RegExp(
    "${RegExp.escape(name)}\\s*=\\s*['\"]([^'\"<>]+)['\"]",
    caseSensitive: false,
  );
  final m = rx.firstMatch(tag);
  return m?.group(1);
}

/// ======== 2D Affine transform (SVG) ========

class _Mat2D {
  final double a, b, c, d, e, f; // [a c e; b d f; 0 0 1]
  const _Mat2D(this.a, this.b, this.c, this.d, this.e, this.f);

  static const I = _Mat2D(1, 0, 0, 1, 0, 0);

  Offset apply(Offset p) =>
      Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  _Mat2D mul(_Mat2D o) => _Mat2D(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  static _Mat2D translate(double tx, double ty) => _Mat2D(1, 0, 0, 1, tx, ty);
  static _Mat2D scale(double sx, double sy) => _Mat2D(sx, 0, 0, sy, 0, 0);
  static _Mat2D matrix(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) => _Mat2D(a, b, c, d, e, f);
}

_Mat2D _parseTransform(String? raw) {
  if (raw == null || raw.trim().isEmpty) return _Mat2D.I;

  final rx = RegExp(r'([a-zA-Z]+)\s*\(([^)]*)\)');
  _Mat2D acc = _Mat2D.I;

  for (final m in rx.allMatches(raw)) {
    final cmd = m.group(1)!.toLowerCase();
    final params = m
        .group(2)!
        .split(RegExp(r'[,\s]+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => double.tryParse(s) ?? 0.0)
        .toList();

    switch (cmd) {
      case 'translate':
        final tx = params.isNotEmpty ? params[0] : 0.0;
        final ty = params.length > 1 ? params[1] : 0.0;
        acc = acc.mul(_Mat2D.translate(tx, ty));
        break;
      case 'scale':
        final sx = params.isNotEmpty ? params[0] : 1.0;
        final sy = params.length > 1 ? params[1] : sx;
        acc = acc.mul(_Mat2D.scale(sx, sy));
        break;
      case 'matrix':
        if (params.length >= 6) {
          acc = acc.mul(
            _Mat2D.matrix(
              params[0],
              params[1],
              params[2],
              params[3],
              params[4],
              params[5],
            ),
          );
        }
        break;
      // (optional) bisa tambah rotate/skew bila diperlukan
    }
  }
  return acc;
}

/// ======== Loader utama ========
/// Ambil anchor dari <g id="anchors"> berisi <circle>
/// - Dukung transform di <g id="anchors"> dan per-<circle>
/// - cx/cy angka absolut ATAU persen; kalau ada data-xrel/data-yrel, pakai langsung (0..1)
/// - Kalau ada nama ganda → dirata-rata
Future<Map<String, Offset>> loadSvgAnchors(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);

  final vb = _parseViewBoxOrFallback(raw);

  // Tag pembuka <g id="anchors" ...>
  final openRx = RegExp(
    "<g\\b[^>]*\\bid\\s*=\\s*['\"]anchors['\"][^>]*>",
    caseSensitive: false,
  );
  final openMatch = openRx.firstMatch(raw);
  final groupOpenTag = openMatch?.group(0) ?? '';
  final groupTransform = _parseTransform(_getAttr(groupOpenTag, 'transform'));

  // Konten dalam anchors group (kalau ada). Kalau tidak, pakai seluruh dokumen.
  final groupBodyMatch = RegExp(
    "<g\\b[^>]*\\bid\\s*=\\s*['\"]anchors['\"][^>]*>([\\s\\S]*?)</g>",
    caseSensitive: false,
  ).firstMatch(raw);
  final scope = groupBodyMatch?.group(1) ?? raw;

  final circleRx = RegExp("<circle\\b[^>]*>", caseSensitive: false);

  // Kumpulkan semua titik per nama → list untuk di-average
  final tmp = <String, List<Offset>>{};

  for (final m in circleRx.allMatches(scope)) {
    final tag = m.group(0)!;

    final name = _getAttr(tag, "data-name") ?? _getAttr(tag, "id");
    if (name == null || name.trim().isEmpty) continue;

    // Relatif langsung?
    final xr = _parseNum(_getAttr(tag, "data-xrel"));
    final yr = _parseNum(_getAttr(tag, "data-yrel"));
    if (xr != null && yr != null) {
      final rel = Offset(xr.clamp(0.0, 1.0), yr.clamp(0.0, 1.0));
      (tmp[name] ??= <Offset>[]).add(rel);
      continue;
    }

    // Absolut (cx/cy) + dukung persen
    final cxRaw = _getAttr(tag, "cx");
    final cyRaw = _getAttr(tag, "cy");
    if (cxRaw == null || cyRaw == null) continue;

    double xAbs, yAbs;

    final px = _parsePercent(cxRaw);
    final py = _parsePercent(cyRaw);
    if (px != null) {
      xAbs = vb.left + px * vb.width;
    } else {
      final xNum = _parseNum(cxRaw);
      if (xNum == null) continue;
      xAbs = xNum;
    }
    if (py != null) {
      yAbs = vb.top + py * vb.height;
    } else {
      final yNum = _parseNum(cyRaw);
      if (yNum == null) continue;
      yAbs = yNum;
    }

    // Transform per-circle + group
    final circleTransform = _parseTransform(_getAttr(tag, 'transform'));
    final world = groupTransform.mul(circleTransform).apply(Offset(xAbs, yAbs));

    final xRel = ((world.dx - vb.left) / vb.width).clamp(0.0, 1.0);
    final yRel = ((world.dy - vb.top) / vb.height).clamp(0.0, 1.0);
    (tmp[name] ??= <Offset>[]).add(Offset(xRel, yRel));
  }

  // Rata-rata bila ada lebih dari 1 anchor per nama
  final out = <String, Offset>{};
  tmp.forEach((name, list) {
    if (list.isEmpty) return;
    final sx = list.fold<double>(0, (a, b) => a + b.dx);
    final sy = list.fold<double>(0, (a, b) => a + b.dy);
    out[name] = Offset(sx / list.length, sy / list.length);
  });

  return out;
}
