import 'dart:ui';
import 'package:flutter/material.dart';

class HomeBottomActions extends StatelessWidget {
  const HomeBottomActions({
    super.key,
    this.onExploreMap,
    this.onListStories,
    this.onFilterRegion,
  });

  final VoidCallback? onExploreMap;
  final VoidCallback? onListStories;
  final VoidCallback? onFilterRegion;

  @override
  Widget build(BuildContext context) {
    final gap = MediaQuery.of(context).size.width < 360 ? 6.0 : 10.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ActionPill(
            icon: Icons.public_rounded,
            label: 'Jelajahi Peta',
            onTap: onExploreMap ?? () {},
          ),
          SizedBox(width: gap),
          _ActionPill(
            icon: Icons.menu_book_rounded,
            label: 'Daftar Cerita',
            onTap:
                onListStories ??
                () => Navigator.of(context).pushNamed('/library'),
          ),
          SizedBox(width: gap),
          _ActionPill(
            icon: Icons.filter_alt_rounded,
            label: 'Filter Wilayah',
            onTap: onFilterRegion ?? () {},
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
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

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Material(
            color: cs.surface.withOpacity(.65),
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(.22),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: cs.onSurface),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
