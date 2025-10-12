// lib/features/home/widget/fluid_story_card.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fluid_action_card/FluidActionCard/fluid_action_card.dart';

import 'package:jejak_cerita_rakyat/core/widgets/story_image.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart'
    show StoryItem;

class FluidStoryCard extends StatelessWidget {
  const FluidStoryCard({super.key, required this.story});
  final StoryItem story;

  // warna & aset
  static const _gold = Color(0xFFE8C35C);
  static const _placeholder = 'assets/images/covers/default_cover.png';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return RepaintBoundary(
      key: ValueKey('fluid-card-${story.id}'),
      child: InkWell(
        borderRadius: radius,
        onTap: () =>
            Navigator.of(context).pushNamed('/detail', arguments: story),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            // gambar utama (dipakai dua kali: backdrop & foreground)
            // NOTE:
            // - Jika helper `storyImage` belum mendukung `gaplessPlayback`,
            //   aktifkan di dalamnya (Image.asset/network) atau ganti dengan Image langsung.
            final fg = storyImage(
              story.coverAsset,
              fit: BoxFit.contain, // tanpa distorsi
              alignment: Alignment.center,
              gaplessPlayback:
                  true, // <- penting untuk kurangi flicker saat rebuild
            );
            final bg = storyImage(
              story.coverAsset,
              fit: BoxFit.cover, // memenuhi frame (boleh crop)
              alignment: Alignment.center,
              gaplessPlayback: true,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // === LATAR FLUID ===
                // Bungkus dengan ClipRRect agar animasi tidak "bocor" di sudut
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: RepaintBoundary(
                      child: FluidActionCard(
                        // Hindari double onTap: kita pakai InkWell luar saja
                        ontap: null,
                        // Warna/ukuran mengikuti kode semula
                        color1: const Color(0xFF5EEAD4),
                        color2: Colors.black26,
                        backgroundcolor: Colors.transparent,
                        borderRadius1: radius,
                        borderRadius2: radius,
                        TextPosition_Top: 0,
                        TextPosition_Down: 0,
                        height: h,
                        width: w,
                        CardCount: 1,
                        Position: w + 10,
                        shadow: const BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                        assetimage: _placeholder, // required by package
                        text1: const Text(''),
                        text2: const Text(''),
                      ),
                    ),
                  ),
                ),

                // === KONTEN KARTU: backdrop blur + foreground + border emas ===
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // BACKDROP penuh (cover) → blur + dark overlay
                        bg,
                        BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            color: Colors.black.withValues(alpha: .22),
                          ),
                        ),

                        // FOREGROUND: cover utama tanpa distorsi
                        Center(child: fg),

                        // BORDER tipis supaya rapi (emas)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.all(color: _gold, width: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
