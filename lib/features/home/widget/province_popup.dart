import 'package:flutter/material.dart';
import 'package:jejak_cerita_rakyat/providers/story_provider.dart';
import 'package:jejak_cerita_rakyat/core/widgets/story_image.dart';

void showProvincePopup({
  required BuildContext context,
  required String province,
  required List<StoryItem> items,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ProvinceSheet(province: province, items: items),
  );
}

class _ProvinceSheet extends StatelessWidget {
  final String province;
  final List<StoryItem> items;
  const _ProvinceSheet({required this.province, required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$province (${items.length} Cerita)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...items.map(
              (s) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: storyImage(s.coverAsset, fit: BoxFit.cover),
                  ),
                ),
                title: Text(s.title),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/detail', arguments: s);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
