import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/features/detail/detail_screen.dart';
import 'package:jejak_cerita_rakyat/features/library/favorites_screen.dart';
import 'widgets/book_row_card_basic.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sp = context.read<StoryProvider>();
      if (!sp.isLoading && sp.stories.isEmpty) {
        await sp.loadStories();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // background seperti Home (full screen)
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
                  // HEADER chip
                  Consumer<StoryProvider>(
                    builder: (context, sp, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                              spreadRadius: -4,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // back — bulat chip style Home
                            _RoundIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: 'Kembali',
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 12),

                            // judul
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Library Cerita',
                                    style: theme.textTheme.titleLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sp.stories.length} cerita',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // search — bulat chip style Home
                            _RoundIconButton(
                              icon: _showSearch
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              tooltip: _showSearch
                                  ? 'Tutup Pencarian'
                                  : 'Cari Judul',
                              onTap: () {
                                setState(() => _showSearch = !_showSearch);
                                if (!_showSearch) _searchCtrl.clear();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (_showSearch) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari judul atau sinopsis…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: cs.surface.withValues(alpha: .75),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // LIST
                  Expanded(
                    child: Consumer<StoryProvider>(
                      builder: (context, sp, _) {
                        if (sp.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final q = _searchCtrl.text.trim().toLowerCase();
                        final items = q.isEmpty
                            ? sp.stories
                            : sp.stories.where((s) {
                                final t = s.title.toLowerCase();
                                final syn = (s.synopsis ?? '').toLowerCase();
                                return t.contains(q) || syn.contains(q);
                              }).toList();

                        if (items.isEmpty) {
                          return const Center(child: Text('Tidak ada cerita.'));
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final s = items[i];
                            final fav = sp.isFavorite(s.id);

                            void goDetail() {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(data: s),
                                ),
                              );
                            }

                            return BookRowCardBasic(
                              coverAsset: s.coverAsset,
                              title: s.title,
                              synopsis: s.synopsis ?? '-',
                              onTap: goDetail,

                              // aksi di dalam kartu — ikon bergaya chip
                              isFavorite: fav,
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

                  // BOTTOM: Tombol ke Favorit — gaya chip bottom bar Home
                  const SizedBox(height: 8),
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: cs.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FavoritesScreen(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.favorite_rounded),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Favorit',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

// === tombol bulat gaya chip Home ===
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
