import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/core/widgets/story_image.dart';

class HomeGridviewItem extends StatelessWidget {
  final StoryItem data;
  const HomeGridviewItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/detail', arguments: data),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: SizedBox.expand(
            child: storyImage(
              data.coverAsset,
              fit: BoxFit
                  .cover,
              alignment: Alignment
                  .topCenter,
            ),
          ),
        ),
      ),
    );
  }
}
