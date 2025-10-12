import 'package:flutter/material.dart';

class BookRowCardBasic extends StatelessWidget {
  const BookRowCardBasic({
    super.key,
    required this.coverAsset,
    required this.title,
    required this.synopsis,
    required this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.onDelete,
  });

  final String? coverAsset;
  final String title;
  final String synopsis;
  final VoidCallback onTap;

  // Aksi
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // MAIN ROW
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Cover(coverAsset: coverAsset),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          synopsis,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ACTION OVERLAY (pojok kanan atas) — style chip Home
            if (onFavorite != null || onDelete != null)
              Positioned(
                right: 6,
                top: 6,
                child: Row(
                  children: [
                    if (onFavorite != null)
                      _CircleIconButton(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: isFavorite
                            ? cs.error
                            : cs.onSurface, // merah saat aktif
                        onTap: onFavorite!,
                        tooltip: isFavorite
                            ? 'Hapus dari Favorit'
                            : 'Tambah Favorit',
                      ),
                    if (onDelete != null) const SizedBox(width: 6),
                    if (onDelete != null)
                      _CircleIconButton(
                        icon: Icons.delete_outline_rounded,
                        iconColor: cs.onSurface,
                        onTap: onDelete!,
                        tooltip: 'Hapus cerita',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.coverAsset});
  final String? coverAsset;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 60,
      height: 86,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.menu_book_rounded),
    );

    if (coverAsset == null || coverAsset!.isEmpty) return placeholder;

    final p = coverAsset!;
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          p,
          width: 60,
          height: 86,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        p,
        width: 60,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final btn = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );

    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
