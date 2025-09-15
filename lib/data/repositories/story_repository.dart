import 'package:sqflite/sqflite.dart';
import '../../data/db/app_database.dart';

class StoryRepository {
  final AppDatabase _db;
  StoryRepository(this._db);

  Future<Database> get _database async => _db.database;

  Future<List<Map<String, dynamic>>> fetchStories() async {
    final db = await _database;
    return db.rawQuery('''
      SELECT id, slug, title, synopsis, cover_asset, page_count
      FROM v_story_with_counts
      ORDER BY title COLLATE NOCASE;
    ''');
  }

  Future<List<Map<String, dynamic>>> fetchPages(int storyId) async {
    final db = await _database;
    return db.query(
      'pages',
      columns: [
        'id', 'page_no', 'text_plain', 'text_rich_html',
        'image_asset', 'tts_ssml', 'word_timing_json', 'duration_ms'
      ],
      where: 'story_id = ?',
      whereArgs: [storyId],
      orderBy: 'page_no ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchStories(String q) async {
    final db = await _database;
    final query = q.trim();
    if (query.isEmpty) return [];
    try {
      return db.rawQuery('''
        WITH results AS (
          SELECT s.id, s.title, s.synopsis, s.cover_asset
          FROM stories_fts f
          JOIN stories s ON s.id = f.rowid
          WHERE stories_fts MATCH ?
          UNION
          SELECT s.id, s.title, s.synopsis, s.cover_asset
          FROM pages_fts pf
          JOIN pages p ON p.id = pf.rowid
          JOIN stories s ON s.id = p.story_id
          WHERE pages_fts MATCH ?
          GROUP BY s.id
        )
        SELECT * FROM results
        ORDER BY title COLLATE NOCASE;
      ''', [query, query]);
    } catch (_) {
      return db.rawQuery('''
        SELECT id, title, synopsis, cover_asset
        FROM stories
        WHERE title LIKE '%' || ? || '%' OR synopsis LIKE '%' || ? || '%'
        UNION
        SELECT s.id, s.title, s.synopsis, s.cover_asset
        FROM pages p
        JOIN stories s ON s.id = p.story_id
        WHERE p.text_plain LIKE '%' || ? || '%'
        GROUP BY id
        ORDER BY title COLLATE NOCASE;
      ''', [query, query, query]);
    }
  }
}
