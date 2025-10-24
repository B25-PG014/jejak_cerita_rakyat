import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simpan progres per-story sebagai map: storyId -> pageIndex
class ReadingProgressStore {
  static const _kProgress = 'reading_progress';
  static const _kLastOpened = 'last_opened_story';

  static Future<Map<int, int>> _loadMap() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProgress);
    if (raw == null || raw.isEmpty) return {};
    final Map<String, dynamic> m = jsonDecode(raw);
    final Map<int, int> out = {};
    for (final e in m.entries) {
      final k = int.tryParse(e.key);
      final v = (e.value as num?)?.toInt();
      if (k != null && v != null) out[k] = v;
    }
    return out;
  }

  static Future<void> _saveMap(Map<int, int> map) async {
    final sp = await SharedPreferences.getInstance();
    final enc = map.map((k, v) => MapEntry(k.toString(), v));
    await sp.setString(_kProgress, jsonEncode(enc));
  }

  static Future<int?> getPage(int storyId) async {
    final m = await _loadMap();
    return m[storyId];
  }

  static Future<void> setPage(int storyId, int pageIndex) async {
    final m = await _loadMap();
    m[storyId] = pageIndex;
    await _saveMap(m);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kLastOpened, storyId);
  }

  static Future<void> removeStory(int storyId) async {
    final m = await _loadMap();
    if (m.remove(storyId) != null) {
      await _saveMap(m);
    }
  }

  static Future<int?> getLastOpenedStory() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kLastOpened);
  }
}
