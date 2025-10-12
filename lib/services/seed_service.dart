// lib/services/seed_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/story_repository.dart';

const _kSeedVersion = 5; // naikkan versi agar seed ulang sesuai format baru
const _kSeedFlagKey = 'seed_done_v$_kSeedVersion';

class SeedService {
  final StoryRepository repo;
  SeedService(this.repo);

  Future<void> runOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kSeedFlagKey) ?? false;
    if (done) return;

    // 1) Baca JSON dari asset
    final raw = await rootBundle.loadString('assets/data/F2_story.json');
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw FormatException(
        'f2_story.json diharapkan berupa array top-level berisi story.',
      );
    }

    // 2) Seed jika DB kosong
    final count = await repo.countStories();
    if (count == 0) {
      // (Opsional) bersihkan dummy jika sebelumnya pernah tersimpan
      await repo.deleteStoriesByTitlePatterns(['nenek', 'gabus']);
      await repo.deleteStoriesByTitlePatterns(['nenek tua', 'ikan gabus']);

      await repo.bulkInsertStoriesWithNestedPagesFromTopLevelList(decoded);
    }

    await repo.linkProvincesForExistingStoriesFromJsonTopLevelList(decoded);
    await prefs.setBool(_kSeedFlagKey, true);
  }
}
