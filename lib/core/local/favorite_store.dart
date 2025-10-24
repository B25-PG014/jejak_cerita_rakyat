import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStore {
  static const _kFav = 'favorite_story_ids'; // disimpan sebagai JSON array

  static Future<Set<int>> getFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFav);
    if (raw == null || raw.isEmpty) return <int>{};
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => (e as num?)?.toInt()).whereType<int>().toSet();
  }

  static Future<void> saveFavorites(Set<int> ids) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFav, jsonEncode(ids.toList()));
  }

  static Future<void> add(int id) async {
    final s = await getFavorites();
    s.add(id);
    await saveFavorites(s);
  }

  static Future<void> remove(int id) async {
    final s = await getFavorites();
    s.remove(id);
    await saveFavorites(s);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kFav);
  }
}
