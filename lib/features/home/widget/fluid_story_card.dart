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
    return LayoutBuilder(
      builder: (context, c) {
        // ukuran dari sel grid
        final w = c.maxWidth;
        final h = c.maxHeight;
        final radius = BorderRadius.circular(16);

        // gambar utama (akan dipakai dua kali, backdrop & foreground)
        final fg = storyImage(
          story.coverAsset,
          fit: BoxFit.contain, // TANPA distorsi
          alignment: Alignment.center,
        );
        final bg = storyImage(
          story.coverAsset,
          fit: BoxFit.cover, // memenuhi frame (boleh crop)
          alignment: Alignment.center,
        );

        return InkWell(
          borderRadius: radius,
          onTap: () =>
              Navigator.of(context).pushNamed('/detail', arguments: story),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // — Frame fluid sebagai latar
              Positioned.fill(
                child: FluidActionCard(
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
                  ontap: () => Navigator.of(
                    context,
                  ).pushNamed('/detail', arguments: story),
                ),
              ),

              // — KONTEN KARTU: backdrop cover (blur) + foreground contain + border
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // BACKDROP: isi penuh (cover) → blur + gelap tipis
                      bg,
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(color: Colors.black.withOpacity(.22)),
                      ),

                      // FOREGROUND: gambar utama tanpa distorsi
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
          ),
        );
      },
    );
  }
}
