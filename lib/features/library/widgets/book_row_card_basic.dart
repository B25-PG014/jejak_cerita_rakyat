import 'dart:io';
import 'package:flutter/material.dart';

class BookRowCardBasic extends StatelessWidget {
  const BookRowCardBasic({
    super.key,
    required this.coverAsset,
    required this.title,
    required this.synopsis,
    required this.onTap,
  });

  final String? coverAsset;
  final String title;
  final String synopsis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Colors.black.withOpacity(0.72);
    final onPanel = Colors.white;
    final border = Colors.white.withOpacity(.18);

    final w = MediaQuery.of(context).size.width;
    final coverWidth = (w * 0.28).clamp(96.0, 140.0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // -> Bungkus dengan tinggi pasti supaya ListView punya ukuran anak yang jelas
        child: SizedBox(
          height: 134,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // COVER
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: coverWidth,
                  child: _buildCover(coverAsset),
                ),
              ),
              const SizedBox(width: 12),

              // PANEL TEKS
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 1),
                  ),
                  child: DefaultTextStyle(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: onPanel),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // JANGAN pakai Expanded/Flexible di sini untuk menghindari ParentDataWidget error
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: onPanel,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        // Cukup Text dengan maxLines (tanpa Expanded)
                        Text(
                          (synopsis.isEmpty) ? '-' : synopsis,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: onPanel, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Loader cover yang anti-crash + bersihkan kutip ganda di path =====
  Widget _buildCover(String? path0) {
    if (path0 == null || path0.isEmpty) return _coverFallback();

    // Hilangkan kutip yang ikut tersimpan di DB: "assets/...png"
    final path = path0.trim().replaceAll(RegExp(r'^"+|"+$'), '');
    final lower = path.toLowerCase();

    if (lower.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverFallback(),
      );
    }
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverFallback(),
      );
    }

    // Path lokal absolut (hasil copy ke Documents/stories/<slug>/...)
    try {
      final f = File(path);
      if (!f.existsSync()) return _coverFallback();
      return Image.file(
        f,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverFallback(),
      );
    } catch (_) {
      return _coverFallback();
    }
  }

  Widget _coverFallback() => Container(
    color: Colors.grey.shade300,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
  );
}
