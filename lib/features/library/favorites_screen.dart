import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/features/detail/detail_screen.dart';
import 'widgets/book_row_card_basic.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // FULLSCREEN BACKGROUND (sama seperti Home)
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  // Header chip gaya Home
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                          tooltip: 'Kembali',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Favorit',
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.favorite_rounded, color: Colors.red),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // LIST FAVORIT
                  Expanded(
                    child: Consumer<StoryProvider>(
                      builder: (context, sp, _) {
                        final favIds = sp.favoriteIds;
                        final items = sp.stories
                            .where((s) => favIds.contains(s.id))
                            .toList();

                        if (items.isEmpty) {
                          return const Center(
                            child: Text('Belum ada cerita favorit.'),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final s = items[i];
                            return BookRowCardBasic(
                              coverAsset: s.coverAsset,
                              title: s.title,
                              synopsis: s.synopsis ?? '-',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(data: s),
                                  ),
                                );
                              },
                              isFavorite: true,
                              onFavorite: () => sp.toggleFavorite(s.id),
                              onDelete: () async {
                                await sp.deleteStory(s.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      'Cerita "${s.title}" dihapus',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final btn = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: cs.onSurface),
      ),
    );

    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
