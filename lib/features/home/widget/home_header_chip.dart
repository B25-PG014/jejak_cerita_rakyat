import 'package:flutter/material.dart';

class HomeHeaderChip extends StatelessWidget {
  const HomeHeaderChip({
    super.key,
    this.onTapSearch,
    this.onTapSettings, // NEW: callback optional buat gear
  });

  final VoidCallback? onTapSearch;
  final VoidCallback? onTapSettings; // NEW

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // avatar / logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.menu_book_rounded, size: 20),
          ),
          const SizedBox(width: 10),

          // title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jejak Cerita Rakyat',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Jelajahi warisan Nusantara',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // ACTIONS: settings + search
          Row(
            children: [
              IconButton(
                tooltip: 'Pengaturan',
                onPressed: onTapSettings, // <- panggil kalau disediakan
                icon: const Icon(Icons.settings), // GEAR kembali
              ),
              IconButton(
                tooltip: 'Cari',
                onPressed: onTapSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
